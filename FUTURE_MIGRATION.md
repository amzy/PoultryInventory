# Future migration format

Cashew migration parsing is centralized in `lib/services/cashew_migration_parser.dart`.
Future Cashew imports should provide a JSON object with a `records` array. Each record may contain:

- `transactionId`
- `date`
- `mainCategory`
- `category` or `originalCategory`
- `account` / `walletName`
- `description` / `name` / `note`
- `amount`
- `unit`
- `quantity`
- `income` / `isIncome`

The parser normalizes only mappings explicitly configured in `ExpenseCategoryConfig`, including:
Layer Feed -> Feed, Stone -> Grit, Health/Dr Fee/Healthcare -> Medical,
Construction Labor/Steel Labor/Labor work -> Labor, Construction Materials -> Materials,
Material -> Material, Vaccine -> Vaccine.

Main category and subcategory are independent dimensions, so the same subcategory can exist under different main categories.
Account is preserved as a first-class transaction field. Income transactions are stored as `transactionType=credit`; all other transactions are `expense`.
