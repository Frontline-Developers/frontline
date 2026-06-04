import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/feed_datasource.dart';
import '../../data/repositories/feed_repository_impl.dart';
import '../../domain/entities/news_item.dart';

class FeedState {
  final List<NewsItem> items;
  final bool isLoading;
  final String? error;
  const FeedState({this.items = const [], this.isLoading = false, this.error});

  FeedState copyWith({
    List<NewsItem>? items,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return FeedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

final _feedDatasourceProvider = Provider((_) => FeedDatasourceImpl());
final _feedRepositoryProvider = Provider(
  (ref) => FeedRepositoryImpl(ref.watch(_feedDatasourceProvider)),
);

final feedNotifierProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);

class FeedNotifier extends Notifier<FeedState> {
  @override
  FeedState build() {
    final sub = ref
        .watch(_feedRepositoryProvider)
        .watchFeed()
        .listen(
          (items) => state = state.copyWith(items: items, isLoading: false),
          onError: (e) =>
              state = state.copyWith(isLoading: false, error: e.toString()),
        );
    ref.onDispose(sub.cancel);
    return const FeedState(isLoading: true);
  }
}
