const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const { DateTime } = require('luxon');

admin.initializeApp();
setGlobalOptions({ region: 'asia-south1', maxInstances: 5 });
const db = admin.firestore();
const messaging = admin.messaging();

function interpolate(text, values) {
  return (text || '').replace(/\{(memberName|flockName|breedName|date)\}/g, (_, k) => values[k] || '');
}

async function tokensFor(uid) {
  const snap = await db.collection('users').doc(uid).collection('devices').get();
  return snap.docs.map(d => d.data().token).filter(Boolean);
}

async function sendToMember(uid, language, payload, values) {
  const tokens = await tokensFor(uid);
  if (!tokens.length) return 0;
  const title = interpolate(language === 'hi' ? payload.titleHi : payload.titleEn, values);
  const body = interpolate(language === 'hi' ? payload.bodyHi : payload.bodyEn, values);
  const response = await messaging.sendEachForMulticast({ tokens, notification: { title, body }, data: { type: payload.type || 'poultry_notification', flockId: values.flockId || '' } });
  const invalid = [];
  response.responses.forEach((r, i) => { if (!r.success && ['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(r.error?.code)) invalid.push(tokens[i]); });
  if (invalid.length) {
    const batch = db.batch();
    const snap = await db.collection('users').doc(uid).collection('devices').get();
    snap.docs.filter(d => invalid.includes(d.data().token)).forEach(d => batch.delete(d.ref));
    await batch.commit();
  }
  return response.successCount;
}

exports.sendFlockNotification = onDocumentCreated('flocks/{flockId}/notification_requests/{requestId}', async event => {
  const request = event.data?.data();
  if (!request || request.status !== 'pending') return;
  const flockId = event.params.flockId;
  const flockSnap = await db.doc(`flocks/${flockId}`).get();
  if (!flockSnap.exists) return;
  const flock = flockSnap.data();
  const members = request.memberUid
    ? [await db.doc(`flocks/${flockId}/members/${request.memberUid}`).get()]
    : (await db.collection(`flocks/${flockId}/members`).get()).docs;
  let sent = 0;
  for (const m of members) {
    if (!m.exists) continue;
    const md = m.data();
    sent += await sendToMember(m.id, md.notificationLanguage === 'hi' ? 'hi' : 'en', request, {
      memberName: md.displayName || md.email || 'Member', flockName: flock.name || 'Flock', breedName: flock.breedName || '', date: DateTime.now().toFormat('dd MMM yyyy'), flockId
    });
  }
  await event.data.ref.update({ status: 'sent', sent, sentAt: admin.firestore.FieldValue.serverTimestamp() });
});

exports.dailyReportReminder = onSchedule({ schedule: 'every 15 minutes', timeZone: 'Asia/Kolkata' }, async () => {
  const flocks = await db.collection('flocks').where('endDate', '==', null).get();
  const now = DateTime.now().setZone('Asia/Kolkata');
  const dateKey = now.toFormat('yyyy-MM-dd');
  for (const flockDoc of flocks.docs) {
    const flock = flockDoc.data();
    const settingsDoc = await flockDoc.ref.collection('notification_settings').doc('config').get();
    const settings = settingsDoc.exists ? settingsDoc.data() : {};
    if (settings.enabled === false || settings.dailyReportReminder === false) continue;
    const h = Number(settings.reminderHour ?? 20), min = Number(settings.reminderMinute ?? 0);
    const currentMinute = now.hour * 60 + now.minute;
    if (Math.abs(currentMinute - (h * 60 + min)) > 7) continue;
    const log = await flockDoc.ref.collection('daily_logs').doc(dateKey).get();
    if (log.exists) continue;
    const templateDoc = await flockDoc.ref.collection('notification_templates').doc('daily_report_reminder').get();
    const template = templateDoc.exists ? templateDoc.data() : {
      titleEn:'Daily Report Reminder', titleHi:'दैनिक रिपोर्ट रिमाइंडर',
      bodyEn:"Today's daily report for {flockName} has not been submitted.", bodyHi:'{flockName} की आज की दैनिक रिपोर्ट अभी दर्ज नहीं की गई है।'
    };
    const members = await flockDoc.ref.collection('members').get();
    for (const m of members.docs) {
      const md = m.data();
      if (md.receiveDailyReminder === false) continue;
      await sendToMember(m.id, md.notificationLanguage === 'hi' ? 'hi' : 'en', { ...template, type:'daily_report_reminder' }, { memberName:md.displayName||md.email||'Member', flockName:flock.name||'Flock', breedName:flock.breedName||'', date:now.toFormat('dd MMM yyyy'), flockId:flockDoc.id });
    }
  }
});

// -----------------------------------------------------------------------------
// Daily egg market prices
// -----------------------------------------------------------------------------
// The market-price collector is intentionally server-side. Flutter/mobile/web
// clients only read Firestore, so no provider credentials are exposed.
const MARKETS = [
  { id: 'ajmer', name: 'Ajmer', slug: 'ajmer-egg-rates' },
  { id: 'jaipur', name: 'Jaipur', slug: 'jaipur-egg-rates' },
  { id: 'jodhpur', name: 'Jodhpur', slug: 'jodhpur-egg-rates' },
  { id: 'kota', name: 'Kota', slug: 'kota-egg-rates' },
  { id: 'udaipur', name: 'Udaipur', slug: 'udaipur-egg-rates' },
  { id: 'delhi', name: 'Delhi', slug: 'delhi-egg-rates' },
  { id: 'ahmedabad', name: 'Ahmedabad', slug: 'ahmedabad-egg-rates' },
  { id: 'mumbai', name: 'Mumbai', slug: 'mumbai-egg-rates' },
];

function priceNumber(value) {
  if (value == null) return null;
  const cleaned = String(value).replace(/,/g, '');
  const match = cleaned.match(/\d+(?:\.\d+)?/);
  if (!match) return null;
  const n = Number(match[0]);
  return Number.isFinite(n) ? n : null;
}

function todayIst() {
  return DateTime.now().setZone('Asia/Kolkata').toFormat('yyyy-MM-dd');
}

async function fetchEggRatesIn(market) {
  const url = `https://eggrates.in/${market.slug}`;
  const response = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; OvalOasisPoultryInventory/1.0)',
      'Accept': 'text/html,application/xhtml+xml',
    },
  });
  if (!response.ok) throw new Error(`EggRates.in HTTP ${response.status}`);

  const html = await response.text();

  // Prefer the explicit per-egg value. Keep several fallbacks because the
  // provider can change markup without notice.
  const patterns = [
    /₹\s*([0-9]+(?:\.[0-9]+)?)\s*(?:per\s*)?egg/gi,
    /([0-9]+(?:\.[0-9]+)?)\s*₹?\s*(?:\/|per)\s*egg/gi,
    /(?:egg\s*rate|rate\s*per\s*egg)[^0-9]{0,80}₹?\s*([0-9]+(?:\.[0-9]+)?)/gi,
  ];

  let rate = null;
  for (const pattern of patterns) {
    const matches = [...html.matchAll(pattern)];
    if (matches.length) {
      for (const match of matches) {
        const candidate = priceNumber(match[1]);
        // Indian egg rates should be in a sensible per-egg range. This avoids
        // accidentally capturing a date, phone number, or unrelated amount.
        if (candidate != null && candidate >= 1 && candidate <= 50) {
          rate = candidate;
          break;
        }
      }
    }
    if (rate != null) break;
  }

  if (rate == null) throw new Error('EggRates.in page did not contain a valid per-egg rate');

  return {
    today: rate,
    source: 'EggRates.in / NECC',
    sourceUrl: url,
    sourceDate: todayIst(),
  };
}

async function syncEggMarket(market) {
  const ref = db.collection('market_prices').doc(market.id);
  const previousSnap = await ref.get();
  const previousData = previousSnap.exists ? previousSnap.data() : {};
  const previous = priceNumber(previousData?.todayPrice);

  try {
    const live = await fetchEggRatesIn(market);
    const change = previous == null ? null : Number((live.today - previous).toFixed(4));
    const percent = previous == null || previous === 0
      ? null
      : Number(((change / previous) * 100).toFixed(2));

    await ref.set({
      marketId: market.id,
      marketName: market.name,
      todayPrice: live.today,
      yesterdayPrice: previous,
      change,
      percent,
      pricePerTray: Number((live.today * 30).toFixed(2)),
      pricePer100: Number((live.today * 100).toFixed(2)),
      dateKey: live.sourceDate,
      source: live.source,
      sourceUrl: live.sourceUrl,
      status: 'live',
      checkedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      error: admin.firestore.FieldValue.delete(),
    }, { merge: true });

    return { market: market.name, status: 'live', today: live.today, change, percent };
  } catch (error) {
    const message = error?.message || String(error);
    await ref.set({
      marketId: market.id,
      marketName: market.name,
      status: 'unavailable',
      error: message,
      checkedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { market: market.name, status: 'unavailable', error: message };
  }
}

async function syncAllEggMarkets() {
  const results = [];
  // Sequential requests are gentler on the public source and avoid bursts.
  for (const market of MARKETS) {
    results.push(await syncEggMarket(market));
  }
  return results;
}

exports.syncEggMarketPrices = onSchedule({
  schedule: '15 6 * * *',
  timeZone: 'Asia/Kolkata',
  region: 'asia-south1',
  timeoutSeconds: 120,
  memory: '256MiB',
}, async () => {
  await syncAllEggMarkets();
});

exports.refreshEggMarketPrices = onCall({
  region: 'asia-south1',
  timeoutSeconds: 120,
  memory: '256MiB',
}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');

  const profile = await db.collection('users').doc(request.auth.uid)
    .collection('profile').doc('account').get();
  if (profile.data()?.role !== 'admin') {
    throw new HttpsError('permission-denied', 'Only farm admins can refresh market prices.');
  }

  return { results: await syncAllEggMarkets() };
});

