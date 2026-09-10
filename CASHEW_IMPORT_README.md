# Cashew SQLite Import

The Settings screen imports the original Cashew SQLite export directly. Cashew files commonly use a `.sql` extension even though the file itself is a SQLite 3 database.

## Safe reset + import workflow

The current migration data can be discarded while the sync is being finalized because imported records are identifiable by their `cashew_` document IDs.

1. In **Settings**, choose **Delete Old Imported Cashew Data**.
2. Confirm the deletion.
3. Choose **Sync Cashew SQLite Data** and select the original SQLite export.
4. Verify the imported totals and categories before starting new financial data entry.

The delete action removes only importer-created `cashew_*` expense records. Manual expense records and Daily Logs are not deleted.

## Sync behavior

Each Cashew transaction gets a deterministic Firestore ID:

`cashew_<transactionId>`

After the initial clean import, importing the same SQLite export again is an upsert/sync:

- New transaction → imported.
- Existing transaction with identical current values → unchanged.
- Existing transaction whose category, account, amount, description, date, unit, quantity, or expense/credit type differs → updated.

## Current category mappings

Only these financial main categories are valid:

- Layer Bird
- Chiks
- Renovation
- Augar Work

Cashew source mappings include:

- Layer Feed → Layer Bird / Feed
- Stone → Layer Bird / Grit
- Health → Layer Bird / Medical
- Dr Fee → Chiks / Medical
- Healthcare → Chiks / Medical
- Vaccine → corresponding main category / Vaccine
- Construction Labor → Renovation / Labor
- Construction Materials → Renovation / Material
- Steel Labor → Renovation / Labor
- Material → Augar Work / Material
- Labor work → Augar Work / Labor
- Electricity → Layer Bird / Electricity

If the source has no separate subcategory and the source category is itself a top-level work category, it maps to `Other Expenses` while `originalCategory` preserves the source value.

Unsupported source categories/subcategories are rejected before Firestore writes begin, so an unexpected source record cannot silently create data outside the current model.

## Account preservation

The source account is copied to each transaction. The current known accounts are:

- Amzad Khan
- Sarfaraj Khan

The importer does not merge accounts.

## Web build requirement

The SQLite WASM runtime must exist at `web/sqlite3.wasm` for browser imports. Run:

```bash
./scripts/setup_sqlite_web.sh
```

before building the web app.


## Flock-aware backup and import

Financial SQL export is always generated from the currently selected flock. The
export includes flock metadata in SQL comments (`Flock ID`, `Flock Name`, and
`Breed`) while transaction rows remain portable.

A Cashew SQLite/SQL import is written into the currently selected flock only.
Imported source accounts are preserved and added to that flock's account list
when they are not already configured. Re-importing the same Cashew source uses
deterministic `cashew_<transactionId>` document IDs, so it updates changed
transactions instead of creating duplicates.

Normal Cashew imports are attributed to the currently signed-in administrator;
there is no hard-coded Amzad administrator UID in the runtime import path.
