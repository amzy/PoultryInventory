import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for the Poultry Inventory Firebase project.
/// Project: poultryinventory (395473159192)
/// Android/iOS package and bundle ID: com.amzy.poultryinventory
/// Web App ID: 1:395473159192:web:c5655ee975a4b6e36fef6d
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyCeOx2tor6BHvENN-sgbYuwHBEmncLm7QA',
        appId: '1:395473159192:web:c5655ee975a4b6e36fef6d',
        messagingSenderId: '395473159192',
        projectId: 'poultryinventory',
        authDomain: 'poultryinventory.firebaseapp.com',
        storageBucket: 'poultryinventory.firebasestorage.app',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'AIzaSyCeOx2tor6BHvENN-sgbYuwHBEmncLm7QA',
          appId: '1:395473159192:android:3ae327a155b9676d6fef6d',
          messagingSenderId: '395473159192',
          projectId: 'poultryinventory',
          storageBucket: 'poultryinventory.firebasestorage.app',
        );
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDQH1d9Abm3r4w6LJFnEU4fwpOQ4AsKIWo',
          appId: '1:395473159192:ios:4e4f8527e476a6056fef6d',
          messagingSenderId: '395473159192',
          projectId: 'poultryinventory',
          storageBucket: 'poultryinventory.firebasestorage.app',
          iosBundleId: 'com.amzy.poultryinventory',
        );
      default:
        throw UnsupportedError('Firebase is not configured for this platform.');
    }
  }
}
