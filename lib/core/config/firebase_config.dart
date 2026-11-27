import 'package:firebase_core/firebase_core.dart';

const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyB7h2kuVM8CvhNlkptsPtyKXXHUO4T1RQk',
  appId: '1:442982526142:web:6daaf45238e0cf8de442ef',
  messagingSenderId: '442982526142',
  projectId: 'findmybus-535ae',
  authDomain: 'findmybus-535ae.firebaseapp.com',
  storageBucket: 'findmybus-535ae.firebasestorage.app',
);

// Public configuration of the native app registered in the same Firebase project.
// Without build-time options the Firebase SDK uses its bundled platform configuration.
FirebaseOptions? nativeFirebaseOptions(bool ios) {
  final id = ios
      ? const String.fromEnvironment('FIREBASE_IOS_APP_ID')
      : const String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  final key = ios
      ? const String.fromEnvironment('FIREBASE_IOS_API_KEY')
      : const String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  if (id.isEmpty && key.isEmpty) return null;
  if (id.isEmpty || key.isEmpty)
    throw StateError(
      'Both the native Firebase app ID and its API key are required.',
    );
  return FirebaseOptions(
    appId: id,
    apiKey: key,
    projectId: firebaseOptions.projectId,
    messagingSenderId: firebaseOptions.messagingSenderId,
    storageBucket: firebaseOptions.storageBucket,
    iosBundleId: ios ? 'com.bilvok.findmybus' : null,
  );
}
