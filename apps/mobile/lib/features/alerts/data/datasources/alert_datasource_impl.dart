import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/alert_subscription.dart';
import 'alert_datasource.dart';

/// Writes alert subscriptions to:
///   user_alerts/{userId}/subscriptions/{autoId}
///
/// Firebase SDK is ONLY called here — never outside a datasource.
class AlertDatasourceImpl implements AlertDatasource {
  final FirebaseFirestore _firestore;

  AlertDatasourceImpl([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<String> save(AlertSubscription subscription) async {
    try {
      final col = _firestore
          .collection('user_alerts')
          .doc(subscription.userId)
          .collection('subscriptions');

      final doc = await col.add({
        'userId': subscription.userId,
        'locationLabel': subscription.locationLabel,
        'lat': subscription.lat,
        'lng': subscription.lng,
        'radiusKm': subscription.radiusKm,
        'categories': subscription.categories,
        'createdAt': Timestamp.fromDate(subscription.createdAt),
      });

      return doc.id;
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          throw const AlertSaveException(
            'Permission denied. Please try again later.',
          );
        case 'unavailable':
          throw const AlertSaveException(
            'Service unavailable. Check your connection and try again.',
          );
        case 'not-found':
          throw const AlertSaveException(
            'Could not save alert. Please try again.',
          );
        default:
          throw const AlertSaveException(
            'Something went wrong. Please try again.',
          );
      }
    }
  }
}
