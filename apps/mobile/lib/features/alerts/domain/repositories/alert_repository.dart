import '../entities/alert_subscription.dart';

abstract interface class AlertRepository {
  /// Saves [subscription] and returns the generated document id.
  Future<String> save(AlertSubscription subscription);
}
