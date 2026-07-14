// Firebase configuration for AI Form & Vault.
//
// Hand-written (matching what `flutterfire configure` would generate) since
// this app ships Android only. The API key here is the Android client key —
// it is package-name + SHA restricted by Firebase and is safe to ship in
// the app, exactly as it is inside google-services.json.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'AI Form & Vault ships Android only — no Firebase config for '
          '$defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDv-iSE8ECKl4Rt63sB9IdLL_d-B8mCqog',
    appId: '1:191591955909:android:86542ae4b39b667b085fac',
    messagingSenderId: '191591955909',
    projectId: 'aiautofiller',
    storageBucket: 'aiautofiller.firebasestorage.app',
  );
}
