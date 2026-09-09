# Cashew SQLite Import

The Settings screen imports the original Cashew export directly. Cashew files commonly use a `.sql` extension even though the file is a SQLite 3 database.

## Supported files

- `.sql`
- `.db`
- `.sqlite`
- `.sqlite3`

No JSON conversion is required.

## Import behavior

Each Cashew transaction gets a deterministic Firestore ID:

`cashew_<transactionId>`

The import is an **upsert/sync**, not a skip-only migration:

- New transaction → imported.
- Existing transaction with identical current values → unchanged.
- Existing transaction whose category, account, amount, description, date, unit, quantity, or expense/credit type differs → updated to the current SQLite source and current app mapping rules.

This means importing the same SQLite export again is safe and also repairs older imported transactions that used the previous category mapping.

## Category mappings

The existing explicit mappings remain centralized in `expense_category_config.dart`:

- Layer Feed → Feed
- Stone → Grit
- Health → Medical
- Dr Fee → Medical
- Healthcare → Medical
- Vaccine → Vaccine
- Construction Labor → Labor
- Construction Materials → Materials
- Steel Labor → Labor
- Material → Material
- Labor work → Labor

Unknown categories are preserved rather than guessed.

## Web build requirement

The SQLite WASM runtime must exist at `web/sqlite3.wasm` for browser imports. Run:

```bash
./scripts/setup_sqlite_web.sh
```

before building the web app. The script downloads the matching SQLite WASM build for `sqlite3 2.9.x`.
