import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

abstract interface class FcmTokenService {
  /// Requests notification permission, fetches the FCM token, and writes it
  /// to `user_tokens/{userId}` in Firestore.
  ///
  /// Returns silently if permission is denied or the token is unavailable —
  /// the caller must not depend on this succeeding.
  Future<void> registerToken({required String userId});
}

/// Production implementation — Firebase SDK is ONLY called here.
class FcmTokenServiceImpl implements FcmTokenService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  const FcmTokenServiceImpl(this._messaging, this._firestore);

  @override
  Future<void> registerToken({required String userId}) async {
    // 1. Request permission (iOS shows a dialog; Android ≥13 also requires it).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 2. Get the FCM registration token for this device.
    final token = await _messaging.getToken();
    if (token == null) return;

    // 3. Persist to Firestore — overwrite if token changed.
    await _firestore.doc('user_tokens/$userId').set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
