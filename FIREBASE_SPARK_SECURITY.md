# Firebase Spark Security Checklist

## Current protection

- Google Sign-In through Firebase Authentication.
- Every Firestore path is scoped to the authenticated user's UID.
- No catch-all Firestore rule grants access to future collections.
- Daily Log document IDs are deterministic (`yyyy-MM-dd`).
- Daily Log fields are allow-listed.
- Daily Log calculated values are validated by Firestore Rules.
- Daily Log chain links (`previousDateKey` / `previousEndingBirds`) are validated with `getAfter()` so batched future-log repairs remain internally consistent.
- Daily Log deletion is denied to client SDKs.
- Expense/Sales categories, amounts, quantities, and string lengths are validated.
- Client calculations are centralized in `PoultryCalculationService`.

## Important Spark limitation

Security Rules cannot query the collection to discover the latest earlier Daily Log. The Flutter data layer therefore selects the latest earlier document, and Rules verify that the submitted chain link exists and matches the referenced ending-bird count. This is strong client + rules validation, but it is not equivalent to trusted server-side code.

## Recommended next hardening step

Enable Firebase App Check after the first end-to-end test. Use the platform-appropriate provider for Web, Android, and iOS. Start in monitoring/metrics mode where supported, verify legitimate traffic, then enforce App Check for Firestore. Do not enable enforcement before the production app's App Check configuration is tested.

## Deployment

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## Local validation

Run the calculation tests:

```bash
flutter test test/poultry_calculation_service_test.dart
```

Then validate the Firestore rules with the Firebase/Firestore emulator before making substantial production rule changes.
