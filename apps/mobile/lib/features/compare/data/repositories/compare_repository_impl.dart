import '../../domain/entities/event_cluster.dart';
import '../../domain/repositories/compare_repository.dart';
import '../datasources/compare_datasource.dart';

class CompareRepositoryImpl implements CompareRepository {
  CompareRepositoryImpl(this._datasource);

  final CompareDatasource _datasource;

  @override
  Stream<List<EventCluster>> watchClusters() => _datasource.watchClusters();
}
