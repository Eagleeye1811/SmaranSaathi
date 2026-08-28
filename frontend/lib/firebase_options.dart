// Hand-written, in the shape `flutterfire configure` would generate — no
// FlutterFire CLI login to the project's Firebase account was available in
// this environment, so these values were pulled directly from the Android
// app already registered in the `smaransaathi` Firebase project (Project
// settings → General → Your apps → Android →`google-services.json`).
//
// None of this is a secret. Firebase's own docs are explicit that
// `FirebaseOptions` (API key included) are safe to ship in a client binary —
// access is governed by Firestore/Auth security rules and the Google Cloud
// project's API restrictions, not by keeping these values hidden.
//
// Only Android is configured. iOS and web need one more Firebase-console
// step each (registering an iOS/Web app to get their own `appId`) before
// they can be filled in the same way — see the platform branches below.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web — this project has no '
        'Web app registered in the smaransaathi Firebase console yet. Register one '
        '(Project settings → General → Add app → Web) and fill in its appId/authDomain here.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS — no iOS app is '
          'registered in the smaransaathi Firebase console yet. Register one to get a '
          'GoogleService-Info.plist / iosBundleId and iosAppId, then fill them in here.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android in this project so far.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC2a9PgUOxsIsollGxo0u3I55teBD45cLM',
    appId: '1:282914064806:android:78eab34db170bc4ce1a767',
    messagingSenderId: '282914064806',
    projectId: 'smaransaathi',
    storageBucket: 'smaransaathi.firebasestorage.app',
  );
}
