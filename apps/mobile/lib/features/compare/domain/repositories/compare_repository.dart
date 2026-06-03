import '../entities/event_cluster.dart';

abstract class CompareRepository {
  Stream<List<EventCluster>> watchClusters();
}
