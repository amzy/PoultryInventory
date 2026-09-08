# Firebase Configuration

This project is configured for the Firebase project `poultryinventory`.

## Platform identity

- Android application ID: `com.amzy.poultryinventory`
- iOS bundle ID: `com.amzy.poultryinventory`
- Web Firebase App ID: `1:395473159192:web:c5655ee975a4b6e36fef6d`
- Firebase project ID: `poultryinventory`
- Firebase project number: `395473159192`

## Included configuration files

- `android/app/google-services.json` — Android Firebase app configuration
- `ios/Runner/GoogleService-Info.plist` — iOS Firebase app configuration
- `lib/firebase_options.dart` — Web/Android/iOS FlutterFire configuration

The iOS Firebase plist is ready, but the Xcode `ios/` project is generated on the Mac self-hosted runner with `flutter create --platforms=ios .` as described in the project build instructions.

## Next steps

1. Enable Google provider in Firebase Authentication.
2. Create/enable the Cloud Firestore database.
3. Deploy rules and indexes:

   `firebase deploy --only firestore:rules,firestore:indexes`

4. The project intentionally does not use Cloud Functions so it can remain on the Firebase Spark plan.

5. Build/test each platform.
