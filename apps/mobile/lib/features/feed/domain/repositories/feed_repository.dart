import '../entities/news_item.dart';

abstract class FeedRepository {
  Stream<List<NewsItem>> watchFeed();
}
