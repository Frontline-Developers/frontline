import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/search/data/datasources/search_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SearchDatasourceImpl datasource;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    datasource = SearchDatasourceImpl(prefs);
  });

  group('SearchDatasourceImpl.loadRecentSearches', () {
    test('returns empty list when nothing saved', () async {
      final result = await datasource.loadRecentSearches();
      expect(result, isEmpty);
    });

    test('returns saved terms in order', () async {
      await datasource.saveRecentSearch('term-a');
      await datasource.saveRecentSearch('term-b');
      final result = await datasource.loadRecentSearches();
      expect(result, ['term-b', 'term-a']);
    });
  });

  group('SearchDatasourceImpl.saveRecentSearch', () {
    test('adds new term at front', () async {
      await datasource.saveRecentSearch('alpha');
      final result = await datasource.loadRecentSearches();
      expect(result.first, 'alpha');
    });

    test('deduplicates — re-adds existing term at front', () async {
      await datasource.saveRecentSearch('alpha');
      await datasource.saveRecentSearch('beta');
      await datasource.saveRecentSearch('alpha');
      final result = await datasource.loadRecentSearches();
      expect(result, ['alpha', 'beta']);
    });

    test('keeps at most 8 terms', () async {
      for (var i = 0; i < 10; i++) {
        await datasource.saveRecentSearch('term-$i');
      }
      final result = await datasource.loadRecentSearches();
      expect(result.length, 8);
    });

    test('most recently added term is first after max exceeded', () async {
      for (var i = 0; i < 10; i++) {
        await datasource.saveRecentSearch('term-$i');
      }
      final result = await datasource.loadRecentSearches();
      expect(result.first, 'term-9');
    });
  });

  group('SearchDatasourceImpl.clearRecentSearch', () {
    test('removes the specified term', () async {
      await datasource.saveRecentSearch('alpha');
      await datasource.saveRecentSearch('beta');
      await datasource.clearRecentSearch('alpha');
      final result = await datasource.loadRecentSearches();
      expect(result, ['beta']);
      expect(result, isNot(contains('alpha')));
    });

    test('is no-op when term does not exist', () async {
      await datasource.saveRecentSearch('alpha');
      await datasource.clearRecentSearch('nonexistent');
      final result = await datasource.loadRecentSearches();
      expect(result, ['alpha']);
    });
  });
}
