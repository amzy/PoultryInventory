# Firebase Spark Architecture

Poultry Inventory uses Firebase Authentication + Cloud Firestore and is designed to remain on the Firebase Spark plan. Cloud Functions are intentionally not required.

## Backend

- Firebase Authentication: Google Sign-In.
- Cloud Firestore: per-user farm data.
- Firestore Security Rules: ownership + field validation + calculated-field invariants.
- Firestore indexes: deployed through `firestore.indexes.json`.
- App-side calculation service: `lib/services/poultry_calculation_service.dart`.

## Firestore structure

`users/{uid}/daily_logs/{yyyy-MM-dd}` — one Daily Log per date. The deterministic document ID prevents duplicate dates.

`users/{uid}/expense_records/{date_microseconds}` — expense/sales records.

## Daily Log rules

- Backdated dates are allowed, but future dates are rejected.
- A date can only have one Daily Log.
- Starting Birds comes from the latest earlier log found by the app.
- Mortality cannot exceed Starting Birds.
- Ending Birds = Starting Birds − Mortality.
- Total Eggs = rounded(Trays × 30).
- FCR = Feed Consumed (kg) / Egg Mass (kg), where Egg Mass = Trays × Avg Tray Weight (g) / 1000; FCR is 0 when egg mass is 0.
- Laying % = Total Eggs / Ending Birds × 100, or 0 when ending birds are 0.
- Each saved log stores `previousDateKey` and `previousEndingBirds`. Rules verify that the referenced previous log exists and that the bird count matches, including `getAfter()` validation for batched future-log repairs.
- When a backdated log is inserted, the app recalculates all later logs in chronological order.
- Future-log repair batches are kept at 15 documents because Firestore Security Rules limit document access calls for atomic writes; each Daily Log validation uses one `getAfter()` access.
- Daily Logs are not client-deletable because deletion would break the flock chain.

## Spark-plan limitation

Firestore Rules cannot independently query for the “latest earlier log” in a write. Therefore the app determines the previous log, while Rules verify the supplied chain link and all calculated invariants. This protects the data from inconsistent calculated fields without requiring Cloud Functions, but it does not provide a trusted server-side scheduler or autonomous recalculation.

## Security hardening

- No wildcard catch-all rule is used. New collections are denied until explicitly secured.
- Users can access only their own subcollections.
- Daily Log fields are allow-listed and validated.
- Expense/Sales fields are allow-listed, categories are restricted, and negative amounts/quantities are rejected.
- Daily Log calculated fields cannot be freely changed to inconsistent values.
- Daily Log deletion is denied from client SDKs.

## Deployment

Deploy only Firestore configuration:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Do not run `firebase deploy --only functions` for this Spark architecture.
