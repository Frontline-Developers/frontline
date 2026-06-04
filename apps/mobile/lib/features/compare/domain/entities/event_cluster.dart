import '../../../feed/domain/entities/news_item.dart';

enum EvidenceEval { supports, contradicts, unverified }

class ClusterItem {
  final String id;
  final String title;
  final String? body;
  final NewsSource source;
  final DateTime publishedAt;
  final EvidenceEval eval;
  final int confirmCount;
  final int disputeCount;

  const ClusterItem({
    required this.id,
    required this.title,
    this.body,
    required this.source,
    required this.publishedAt,
    required this.eval,
    required this.confirmCount,
    required this.disputeCount,
  });

  static EvidenceEval evalFromVotes(
    int confirms,
    int disputes,
    NewsSource source,
  ) {
    if (source == NewsSource.wire) return EvidenceEval.supports;
    if (confirms + disputes < 2) return EvidenceEval.unverified;
    if (confirms > disputes) return EvidenceEval.supports;
    if (disputes > confirms) return EvidenceEval.contradicts;
    return EvidenceEval.unverified;
  }
}

class EventCluster {
  final String id;
  final String category;
  final DateTime date;
  final List<ClusterItem> items;

  const EventCluster({
    required this.id,
    required this.category,
    required this.date,
    required this.items,
  });

  int get supportCount =>
      items.where((i) => i.eval == EvidenceEval.supports).length;

  int get contradictCount =>
      items.where((i) => i.eval == EvidenceEval.contradicts).length;
}
