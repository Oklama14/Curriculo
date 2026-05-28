import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'MOCK_API_KEY_FOR_LOCAL_DEV',
    authDomain: 'projeto-curriculo.firebaseapp.com',
    projectId: 'projeto-curriculo',
    storageBucket: 'projeto-curriculo.appspot.com',
    messagingSenderId: '1234567890',
    appId: '1:1234567890:web:mockappid123456',
  );
}
