# Poultry Inventory Firestore migrations

These scripts are **one-time administrative migrations**. They are not part of
normal Flutter application startup and must not be called from the app runtime.

## Expense category migration

`migrate_expense_categories.js` converts the legacy categories to the current
canonical model:

- `Egg_Sales` / `Egg Sale` -> `Egg` + `transactionType=credit`
- `Materials` / `Construction Materials` -> `Material`
- Egg sales freight is reset to `0` because the canonical Egg Sales flow does
  not include freight.
- `expense_subcategories/global` is cleaned so `Egg_Sales` and `Materials` are
  removed and `Egg` / `Material` are present once.

The migration updates existing transaction documents in place; it does not
create duplicate transactions and does not delete transaction documents.

## Setup

From this directory:

```bash
npm install
```

Authenticate the Firebase Admin SDK using either:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/service-account.json
```

or:

```bash
export FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

## Run safely

Always run a dry run first:

```bash
node migrate_expense_categories.js --dry-run
```

Apply the migration only after reviewing the counts:

```bash
node migrate_expense_categories.js --confirm
```

To migrate a single flock:

```bash
node migrate_expense_categories.js --confirm --flock FLOCK_ID
```

Do **not** commit service-account credentials to the repository.
