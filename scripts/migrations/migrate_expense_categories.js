#!/usr/bin/env node

/**
 * ONE-TIME Firestore migration for legacy expense categories.
 *
 * Canonical model:
 *   Egg Sales  -> category: Egg, transactionType: credit
 *   Materials  -> category: Material
 *
 * The migration is intentionally outside the Flutter runtime. Run it once
 * against the production Firestore database using Firebase Admin SDK.
 *
 * Authentication:
 *   - Recommended: GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json
 *   - Or: FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
 *
 * Examples:
 *   node scripts/migrations/migrate_expense_categories.js --dry-run
 *   node scripts/migrations/migrate_expense_categories.js --confirm
 *   node scripts/migrations/migrate_expense_categories.js --confirm --flock JZC2nk9rkEtJQvjxsha8
 */

const admin = require('firebase-admin');

const args = new Set(process.argv.slice(2));
const confirm = args.has('--confirm');
const dryRun = args.has('--dry-run') || !confirm;
const flockArgIndex = process.argv.indexOf('--flock');
const requestedFlock = flockArgIndex >= 0 ? process.argv[flockArgIndex + 1] : null;

const projectId = process.env.FIREBASE_PROJECT_ID || 'poultryinventory';

function initialize() {
  if (admin.apps.length > 0) return;

  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });
}

function categoryKey(value) {
  return String(value ?? '')
    .replace(/[^A-Za-z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

function canonicalCategory(value) {
  switch (categoryKey(value)) {
    case 'egg sales':
    case 'egg sale':
      return 'Egg';
    case 'materials':
    case 'material':
    case 'construction materials':
      return 'Material';
    default:
      return null;
  }
}

function canonicalTransactionType(data, canonicalCategory) {
  if (canonicalCategory === 'Egg' &&
      ['egg sales', 'egg sale'].includes(categoryKey(data.category))) {
    return 'credit';
  }
  const current = String(data.transactionType ?? '').trim().toLowerCase();
  return current === 'credit' ? 'credit' : 'expense';
}

async function migrateFlock(db, flockId) {
  const ref = db.collection('flocks').doc(flockId).collection('expense_records');
  const snapshot = await ref.get();

  let scanned = 0;
  let changed = 0;
  let eggSales = 0;
  let materials = 0;
  let batches = 0;

  let batch = db.batch();
  let writes = 0;

  async function commit() {
    if (writes === 0 || dryRun) return;
    await batch.commit();
    batches += 1;
    batch = db.batch();
    writes = 0;
  }

  for (const doc of snapshot.docs) {
    scanned += 1;
    const data = doc.data();
    const canonical = canonicalCategory(data.category);
    if (!canonical) continue;

    if (categoryKey(data.category) === 'egg sales' || categoryKey(data.category) === 'egg sale') {
      eggSales += 1;
    }
    if (categoryKey(data.category) === 'materials') {
      materials += 1;
    }

    const transactionType = canonicalTransactionType(data, canonical);
    const update = {
      category: canonical,
      transactionType,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Egg sales must never carry freight in the canonical model.
    if (canonical === 'Egg' && transactionType === 'credit') {
      update.freightCharge = 0;
    }

    changed += 1;
    if (!dryRun) {
      batch.update(doc.ref, update);
      writes += 1;
      if (writes >= 400) await commit();
    }
  }

  await commit();

  return { flockId, scanned, changed, eggSales, materials, batches };
}

async function migrateGlobalSubcategories(db) {
  const ref = db.collection('expense_subcategories').doc('global');
  const snap = await ref.get();
  if (!snap.exists) return { changed: false, count: 0 };

  const current = Array.isArray(snap.data().items) ? snap.data().items : [];
  const output = [];
  const seen = new Set();

  for (const raw of current) {
    const legacy = canonicalCategory(raw);
    const value = legacy || String(raw ?? '').trim();
    if (!value) continue;
    const key = categoryKey(value);
    if (key === 'egg sales' || key === 'materials') continue;
    if (seen.has(key)) continue;
    seen.add(key);
    output.push(value);
  }

  if (!output.some((value) => categoryKey(value) === 'egg')) output.push('Egg');
  if (!output.some((value) => categoryKey(value) === 'material')) output.push('Material');

  if (dryRun) {
    return { changed: JSON.stringify(output) !== JSON.stringify(current), count: output.length };
  }

  await ref.set({ items: output, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  return { changed: true, count: output.length };
}

async function main() {
  initialize();
  const db = admin.firestore();

  console.log(`Firebase project: ${projectId}`);
  console.log(dryRun
    ? 'MODE: DRY RUN (no Firestore writes). Use --confirm to apply changes.'
    : 'MODE: APPLY (Firestore will be updated).');

  const flocksSnap = requestedFlock
    ? await db.collection('flocks').doc(requestedFlock).get().then((doc) => {
        if (!doc.exists) throw new Error(`Flock not found: ${requestedFlock}`);
        return { docs: [doc] };
      })
    : await db.collection('flocks').get();

  const results = [];
  for (const flock of flocksSnap.docs) {
    const result = await migrateFlock(db, flock.id);
    results.push(result);
    console.log(
      `Flock ${flock.id}: scanned=${result.scanned}, changed=${result.changed}, ` +
      `Egg_Sales=${result.eggSales}, Materials=${result.materials}, batches=${result.batches}`,
    );
  }

  const subcategories = await migrateGlobalSubcategories(db);
  console.log(
    `Global subcategories: ${subcategories.changed ? 'would update/update' : 'already canonical'}, ` +
    `count=${subcategories.count}`,
  );

  const totals = results.reduce((acc, item) => {
    acc.scanned += item.scanned;
    acc.changed += item.changed;
    acc.eggSales += item.eggSales;
    acc.materials += item.materials;
    acc.batches += item.batches;
    return acc;
  }, { scanned: 0, changed: 0, eggSales: 0, materials: 0, batches: 0 });

  console.log('\nMigration summary:');
  console.log(JSON.stringify({ ...totals, dryRun, globalSubcategories: subcategories }, null, 2));

  if (dryRun) {
    console.log('\nNothing was written. Re-run with --confirm to apply the migration.');
  } else {
    console.log('\nMigration completed. The Flutter runtime does not need legacy-category migration code.');
  }
}

main().catch((error) => {
  console.error('\nMigration failed:', error?.stack || error);
  process.exitCode = 1;
});
