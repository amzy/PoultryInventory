# Backward compatibility

This version keeps existing Firestore records readable and editable without requiring a migration that rewrites every document.

## Daily Logs
- Legacy `startingBirds`, `endingBirds`, `previousDateKey`, `previousEndingBirds`, and `layingPercentage` fields are ignored on read.
- Existing logs open in the current Daily Log form.
- Saving an existing log rewrites it to the current Daily Log structure and recalculates total eggs/FCR from the current inputs.
- The original log date cannot be changed during edit because Daily Log document IDs are date-based.

## Expenses
- Existing records without `medicalItems`, `feedItems`, or audit fields continue to load.
- Legacy/unsupported category combinations are opened using the current `Other Expenses` bucket while retaining `originalCategory`.
- A one-time administrative migration is provided in `scripts/migrations/migrate_expense_categories.js` for legacy `Egg_Sales` → `Egg` + `transactionType=credit` and `Materials` → `Material`. It has not been executed automatically by the Flutter runtime. After the migration is run, normal reads use only canonical categories.
- Existing Feed records without feed line items are opened with a current Feed Item line using their legacy quantity/unit price values, allowing manual correction before saving.
- Expense editing uses the same full input form as creating a record.

## Farm configuration
- Existing farm settings without `feedItems` automatically use the five default Feed Items until settings are saved.
