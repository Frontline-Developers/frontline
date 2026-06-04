import '../../../feed/domain/entities/news_item.dart';
import '../repositories/compare_repository.dart';

const _knownLocations = [
  // Ukraine
  'kyiv', 'kharkiv', 'odesa', 'zaporizhzhia', 'lviv', 'mariupol',
  'donetsk', 'luhansk', 'kherson', 'mykolaiv', 'dnipro', 'sumy',
  'chernihiv', 'kramatorsk', 'bakhmut', 'avdiivka', 'bucha', 'irpin',
  'melitopol', 'crimea', 'donbas', 'ukraine',
  // Middle East
  'gaza', 'west bank', 'jerusalem', 'tel aviv', 'beirut', 'damascus',
  'aleppo', 'idlib', 'baghdad', 'mosul', 'fallujah', 'ramadi',
  'iran', 'tehran', 'israel', 'lebanon', 'syria', 'iraq',
  // Africa
  'khartoum', 'port sudan', 'juba', 'mogadishu', 'tripoli', 'benghazi',
  'bamako', 'bangui', 'kinshasa', 'addis ababa', 'tigray', 'sahel',
  'sudan', 'south sudan', 'somalia', 'libya', 'mali', 'niger',
  // Asia
  'kabul', 'kandahar', 'yangon', 'rakhine', 'myanmar', 'afghanistan',
  // Other active regions
  'caracas', 'venezuela', 'haiti',
];

class FetchRelatedWireNewsUseCase {
  final CompareRepository _repo;
  FetchRelatedWireNewsUseCase(this._repo);

  static List<String> extractLocations(String text) {
    final lower = text.toLowerCase();
    return _knownLocations.where((loc) => lower.contains(loc)).toList();
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
