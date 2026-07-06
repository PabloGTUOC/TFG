// Manually written Firebase options, seeded with the same dev fallbacks as
// frontend/src/firebase.js. Replace with real values by running:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// which regenerates this file with per-platform apps (and drops the
// google-services.json / GoogleService-Info.plist files for Android/iOS).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY',
        defaultValue: 'AIzaSy_mock_api_key_for_dev_change_me'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN',
        defaultValue: 'carecoins-dev.firebaseapp.com'),
    projectId:
        String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'carecoins-dev'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET',
        defaultValue: 'carecoins-dev.appspot.com'),
    messagingSenderId:
        String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '123456789'),
    appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:123456789:web:abcdef'),
  );

  // Placeholders until `flutterfire configure` is run for the native apps.
  static const FirebaseOptions android = web;
  static const FirebaseOptions ios = web;
}
