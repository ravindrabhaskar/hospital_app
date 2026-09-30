import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Process-wide initialisation shared by the three bundled apps, done once
/// here instead of once per app.
///
/// Firebase is initialised only when all four FIREBASE_* dart-defines exist
/// (the same rule as the apps). The apps' push services then find
/// `Firebase.apps` non-empty and skip their own `initializeApp`.
Future<void> initSharedServices() async {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
  final configured = apiKey.isNotEmpty && appId.isNotEmpty && senderId.isNotEmpty && projectId.isNotEmpty;
  if (!configured || kIsWeb) return;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
          iosBundleId: iosBundleId == '' ? null : iosBundleId,
        ),
      );
    }
  } catch (e) {
    // The apps treat push as optional; they retry (and fail soft) themselves.
    debugPrint('Firebase init skipped: $e');
  }
}
