import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/compare_datasource.dart';
import '../../data/repositories/compare_repository_impl.dart';
import '../../domain/entities/event_cluster.dart';

class CompareState {
  final List<EventCluster> clusters;
  final bool isLoading;
  final String? error;

  const CompareState({
    this.clusters = const [],
    this.isLoading = false,
    this.error,
  });

  CompareState copyWith({
    List<EventCluster>? clusters,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return CompareState(
      clusters: clusters ?? this.clusters,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

final _compareDatasourceProvider = Provider((_) => CompareDatasourceImpl());
final _compareRepositoryProvider = Provider(
  (ref) => CompareRepositoryImpl(ref.watch(_compareDatasourceProvider)),
);

final compareNotifierProvider = NotifierProvider<CompareNotifier, CompareState>(
  CompareNotifier.new,
);

class CompareNotifier extends Notifier<CompareState> {
  @override
  CompareState build() {
    final sub = ref
        .watch(_compareRepositoryProvider)
        .watchClusters()
        .listen(
          (clusters) =>
              state = state.copyWith(clusters: clusters, isLoading: false),
          onError: (e) =>
              state = state.copyWith(isLoading: false, error: e.toString()),
        );
    ref.onDispose(sub.cancel);
    return const CompareState(isLoading: true);
  }
}
