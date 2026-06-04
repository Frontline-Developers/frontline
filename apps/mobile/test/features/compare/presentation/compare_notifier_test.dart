import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/compare/domain/entities/event_cluster.dart';
import 'package:frontline/features/compare/domain/repositories/compare_repository.dart';
import 'package:frontline/features/compare/presentation/providers/compare_provider.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';

class _FakeRepo implements CompareRepository {
  final StreamController<List<EventCluster>> _ctrl =
      StreamController.broadcast();

  @override
  Stream<List<EventCluster>> watchClusters() => _ctrl.stream;

  @override
  Future<NewsItem> fetchReport(String _) =>
      throw UnimplementedError('not used');

  @override
  Future<List<NewsItem>> fetchWireNewsByLocations(List<String> _) async => [];

  @override
  Future<List<NewsItem>> fetchWireNewsByCategory(String _) async => [];

  @override
  Future<List<NewsItem>> fetchRecentWireNews() async => [];

  void emit(List<EventCluster> clusters) => _ctrl.add(clusters);
  void emitError(Object e) => _ctrl.addError(e);
  Future<void> close() => _ctrl.close();
}

ProviderContainer _container(_FakeRepo repo) => ProviderContainer(
  overrides: [compareRepositoryProvider.overrideWithValue(repo)],
);

final _fakeCluster = EventCluster(
  id: 'c1',
  category: 'combat',
  date: DateTime(2026, 1, 1),
  items: [
    ClusterItem(
      id: 'i1',
      title: 'Strike near Kyiv',
      source: NewsSource.citizen,
      publishedAt: DateTime(2026, 1, 1),
      eval: EvidenceEval.supports,
      confirmCount: 3,
      disputeCount: 0,
    ),
    ClusterItem(
      id: 'i2',
      title: 'Wire confirmation',
      source: NewsSource.wire,
      publishedAt: DateTime(2026, 1, 1, 1),
      eval: EvidenceEval.supports,
      confirmCount: 0,
      disputeCount: 0,
    ),
  ],
);

void main() {
  group('CompareNotifier', () {
    test('initial state: isLoading, empty clusters, no error', () {
      final repo = _FakeRepo();
      final c = _container(repo);
      addTearDown(c.dispose);
      addTearDown(repo.close);

      final state = c.read(compareNotifierProvider);

      expect(state.isLoading, true);
      expect(state.clusters, isEmpty);
      expect(state.error, isNull);
    });

    test('populates clusters when stream emits', () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      addTearDown(c.dispose);
      addTearDown(repo.close);

      c.read(compareNotifierProvider); // subscribe
      repo.emit([_fakeCluster]);
      await Future.microtask(() {});

      final state = c.read(compareNotifierProvider);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.clusters, hasLength(1));
      expect(state.clusters.first.id, 'c1');
    });

    test('sets error state when stream errors', () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      addTearDown(c.dispose);
      addTearDown(repo.close);

      c.read(compareNotifierProvider);
      repo.emitError(StateError('Firestore unavailable'));
      await Future.microtask(() {});

      final state = c.read(compareNotifierProvider);
      expect(state.isLoading, false);
      expect(state.error, isNotNull);
      expect(state.clusters, isEmpty);
    });

    test('replaces clusters on subsequent stream emission', () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      addTearDown(c.dispose);
      addTearDown(repo.close);

      c.read(compareNotifierProvider);
      repo.emit([_fakeCluster]);
      await Future.microtask(() {});
      repo.emit([]);
      await Future.microtask(() {});

      expect(c.read(compareNotifierProvider).clusters, isEmpty);
    });
  });
}
