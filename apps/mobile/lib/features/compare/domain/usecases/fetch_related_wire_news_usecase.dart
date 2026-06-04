import '../../../feed/domain/entities/news_item.dart';
import '../repositories/compare_repository.dart';

const _ukraineLocations = [
  'kyiv',
  'kharkiv',
  'odesa',
  'zaporizhzhia',
  'lviv',
  'mariupol',
  'donetsk',
  'luhansk',
  'kherson',
  'mykolaiv',
  'dnipro',
  'sumy',
  'chernihiv',
  'kramatorsk',
  'bakhmut',
  'avdiivka',
  'bucha',
  'irpin',
  'melitopol',
  'crimea',
  'donbas',
  'ukraine',
];

class FetchRelatedWireNewsUseCase {
  final CompareRepository _repo;
  FetchRelatedWireNewsUseCase(this._repo);

  static List<String> extractLocations(String text) {
    final lower = text.toLowerCase();
    return _ukraineLocations.where((loc) => lower.contains(loc)).toList();
  }

  Future<List<NewsItem>> call({
    required String description,
    required String category,
  }) async {
    final locations = extractLocations(description).take(10).toList();
    if (locations.isNotEmpty) {
      final result = await _repo.fetchWireNewsByLocations(locations);
      if (result.isNotEmpty) return result;
    }

    if (category != 'other') {
      final result = await _repo.fetchWireNewsByCategory(category);
      if (result.isNotEmpty) return result;
    }

    return _repo.fetchRecentWireNews();
  }
}
