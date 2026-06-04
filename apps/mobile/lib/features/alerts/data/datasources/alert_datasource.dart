import '../../domain/entities/alert_subscription.dart';

abstract interface class AlertDatasource {
  Future<String> save(AlertSubscription subscription);
}
