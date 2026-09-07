# Android configuration

Package: `com.amzy.poultryinventory`

This project is configured for Android API/Gradle builds through Flutter.

## Google Sign-In

Register an Android OAuth client in Google Cloud using this package name and the SHA-1 fingerprints for each signing certificate (debug and release). The existing Web OAuth client is used as the server client ID by the Dart integration.

For local development, run `flutter pub get`, then `flutter run -d android`. If your Flutter installation regenerates platform wrapper files, `flutter create --platforms=android .` is safe to run from the project root; keep the package name and launcher resources from this folder.
