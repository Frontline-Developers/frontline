import '../../../feed/domain/entities/news_item.dart';

bool searchMatches(NewsItem item, String query, String scope) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return false;

  final haystack = [
    item.title,
    item.body ?? '',
    item.locations.join(' '),
    item.category ?? '',
    item.sourceName ?? '',
  ].join(' ').toLowerCase();

  final textMatch = words.every((w) => haystack.contains(w));

  final scopeMatch =
      scope == 'all' ||
      (scope == 'citizen' && item.source == NewsSource.citizen) ||
      (scope == 'sources' && item.source == NewsSource.wire);

  return textMatch && scopeMatch;
}
