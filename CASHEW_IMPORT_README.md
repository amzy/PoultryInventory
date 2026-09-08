# Cashew legacy import

The app can import a converted Cashew JSON export from **Settings → Import Cashew Data**.

The supplied conversion contains 96 Cashew transactions and maps them to the Poultry Inventory expense categories. The original Cashew category and note are preserved in each imported description.

The importer uses the original Cashew transaction ID as the Firestore document suffix, so running the same import again skips records that were already imported.

The original Cashew SQLite export is not bundled in the app because the repository is public.
