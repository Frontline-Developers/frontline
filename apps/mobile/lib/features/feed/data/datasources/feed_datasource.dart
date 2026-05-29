import '../../domain/entities/news_item.dart';

abstract class FeedDatasource {
  Stream<List<NewsItem>> watchFeed();
}

// TODO: implement — query Firestore `wire_news` + `reports` collections
class FeedDatasourceImpl implements FeedDatasource {
  @override
  Stream<List<NewsItem>> watchFeed() => Stream.value([]);
}
