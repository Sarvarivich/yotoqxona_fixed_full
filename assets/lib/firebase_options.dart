import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCuRb8k0ul1LXwRrYGL10Z-WIwsFSZ0o0o',
    appId: '1:437568970928:web:0f88a9da458ea49e931b75',
    messagingSenderId: '437568970928',
    projectId: 'yotoqxona-fe7ab',
    authDomain: 'yotoqxona-fe7ab.firebaseapp.com',
    storageBucket: 'yotoqxona-fe7ab.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDQ_c_B-vtRDzGfEb_aOqI3ZfMINMpSZ4k',
    appId: '1:437568970928:android:bdf515ffdc15717d931b75',
    messagingSenderId: '437568970928',
    projectId: 'yotoqxona-fe7ab',
    storageBucket: 'yotoqxona-fe7ab.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCnB9ixOGj9B6Ipx7zpQz2skFTDBJoSlj0',
    appId: '1:437568970928:ios:f88ca76549d026c0931b75',
    messagingSenderId: '437568970928',
    projectId: 'yotoqxona-fe7ab',
    storageBucket: 'yotoqxona-fe7ab.firebasestorage.app',
    iosBundleId: 'com.example.yotoqxona',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCnB9ixOGj9B6Ipx7zpQz2skFTDBJoSlj0',
    appId: '1:437568970928:ios:f88ca76549d026c0931b75',
    messagingSenderId: '437568970928',
    projectId: 'yotoqxona-fe7ab',
    storageBucket: 'yotoqxona-fe7ab.firebasestorage.app',
    iosBundleId: 'com.example.yotoqxona',
  );
}
