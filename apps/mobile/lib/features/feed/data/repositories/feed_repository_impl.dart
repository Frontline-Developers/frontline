import '../../domain/entities/news_item.dart';
import '../../domain/repositories/feed_repository.dart';
import '../datasources/feed_datasource.dart';

class FeedRepositoryImpl implements FeedRepository {
  final FeedDatasource _datasource;
  FeedRepositoryImpl(this._datasource);

  @override
  Stream<List<NewsItem>> watchFeed() => _datasource.watchFeed();
}
