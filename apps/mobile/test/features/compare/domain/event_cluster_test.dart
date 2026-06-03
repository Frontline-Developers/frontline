import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/compare/domain/entities/event_cluster.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';

void main() {
  group('ClusterItem.evalFromVotes', () {
    test('returns supports when confirms > disputes and total >= 2', () {
      final result = ClusterItem.evalFromVotes(3, 1, NewsSource.citizen);
      expect(result, EvidenceEval.supports);
    });

    test('returns contradicts when disputes > confirms and total >= 2', () {
      final result = ClusterItem.evalFromVotes(1, 4, NewsSource.citizen);
      expect(result, EvidenceEval.contradicts);
    });

    test('returns unverified when total < 2', () {
      final result = ClusterItem.evalFromVotes(1, 0, NewsSource.citizen);
      expect(result, EvidenceEval.unverified);
    });

    test('returns unverified when confirms == disputes', () {
      final result = ClusterItem.evalFromVotes(2, 2, NewsSource.citizen);
      expect(result, EvidenceEval.unverified);
    });

    test('wire source always returns supports regardless of vote counts', () {
      final result = ClusterItem.evalFromVotes(0, 5, NewsSource.wire);
      expect(result, EvidenceEval.supports);
    });
  });

  group('EventCluster computed counts', () {
    final items = [
      ClusterItem(
        id: '1',
        title: 'Artillery fire heard',
        source: NewsSource.citizen,
        publishedAt: DateTime(2026, 6, 4, 9),
        eval: EvidenceEval.supports,
        confirmCount: 5,
        disputeCount: 1,
      ),
      ClusterItem(
        id: '2',
        title: 'No damage observed',
        source: NewsSource.citizen,
        publishedAt: DateTime(2026, 6, 4, 10),
        eval: EvidenceEval.contradicts,
        confirmCount: 1,
        disputeCount: 4,
      ),
      ClusterItem(
        id: '3',
        title: 'Reuters: Strike confirmed',
        source: NewsSource.wire,
        publishedAt: DateTime(2026, 6, 4, 11),
        eval: EvidenceEval.supports,
        confirmCount: 0,
        disputeCount: 0,
      ),
    ];

    final cluster = EventCluster(
      id: 'combat_20260604',
      category: 'combat',
      date: DateTime(2026, 6, 4),
      items: items,
    );

    test('supportCount returns number of supporting items', () {
      expect(cluster.supportCount, 2);
    });

    test('contradictCount returns number of contradicting items', () {
      expect(cluster.contradictCount, 1);
    });
  });
}
