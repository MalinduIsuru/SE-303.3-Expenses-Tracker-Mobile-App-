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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDdWpLkJ4Zg1UoAj2pVl3ftjBzI2zqaZYA',
    appId: '1:709452424896:web:706710396b595b527aef25',
    messagingSenderId: '709452424896',
    projectId: 'expensestracker-bbd7b',
    storageBucket: 'expensestracker-bbd7b.appspot.com',
    authDomain: 'expensestracker-bbd7b.firebaseapp.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDdWpLkJ4Zg1UoAj2pVl3ftjBzI2zqaZYA',
    appId: '1:709452424896:android:706710396b595b527aef25',
    messagingSenderId: '709452424896',
    projectId: 'expensestracker-bbd7b',
    storageBucket: 'expensestracker-bbd7b.appspot.com',
  );
}
