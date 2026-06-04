import '../../domain/entities/alert_subscription.dart';
import '../../domain/repositories/alert_repository.dart';
import '../datasources/alert_datasource.dart';

class AlertRepositoryImpl implements AlertRepository {
  final AlertDatasource _datasource;
  const AlertRepositoryImpl(this._datasource);

  @override
  Future<String> save(AlertSubscription subscription) =>
      _datasource.save(subscription);
}
