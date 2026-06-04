import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/alert_subscription.dart';
import 'alert_datasource.dart';

/// Writes alert subscriptions to:
///   user_alerts/{userId}/subscriptions/{autoId}
///
/// Firebase SDK is ONLY called here — never outside a datasource.
class AlertDatasourceImpl implements AlertDatasource {
  final FirebaseFirestore _firestore;

  const AlertDatasourceImpl(this._firestore);

  @override
  Future<String> save(AlertSubscription subscription) async {
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
  }
}
