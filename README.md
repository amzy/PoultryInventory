# poultry_inventory

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## FCM Notifications

The app uses Firebase Cloud Messaging for member notifications. The Flutter client registers each signed-in device under `users/{uid}/devices`. Admin notification settings and bilingual templates are stored under each flock. Cloud Functions process notification requests and scheduled missing-daily-report reminders.

### Deploy backend

From the project root:

```bash
cd functions
npm install
cd ..
firebase deploy --only functions,firestore
```

### Web FCM

Create a Web Push certificate/VAPID key in Firebase Console and build the web app with:

```bash
flutter build web --dart-define=FCM_WEB_VAPID_KEY=YOUR_VAPID_KEY
```

Android/iOS require the normal Firebase Messaging platform setup. On iOS, enable Push Notifications and Background Modes/Remote notifications in Xcode and ensure the Firebase APNs configuration is present.

### Notification placeholders

Templates support `{memberName}`, `{flockName}`, `{breedName}`, and `{date}`. Each member receives the English or Hindi version based on their flock membership `notificationLanguage`.

## One-time legacy flock migration

If this Firebase project contains records created before flock support and no flock exists yet, use `scripts/README_ONE_TIME_MIGRATION.md` to create the initial flock and map the legacy Daily Logs and Expense Records. This is a one-time migration and should be removed after successful verification.

## Live market prices

Dashboard market prices are synchronized server-side by Firebase Cloud Functions into `market_prices/{marketId}`. See `MARKET_PRICE_SERVICE.md` for the mKisan API secret and scheduled-refresh deployment steps.

### Cloud Function log retention

Cloud Function diagnostic logs can be configured for automatic deletion using Google Cloud Logging retention:

```bash
./scripts/configure_log_retention.sh
```

Default retention is 7 days. Override it with `LOG_RETENTION_DAYS=<days>` when needed.
