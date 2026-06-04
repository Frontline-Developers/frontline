import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../feed/domain/entities/news_item.dart';
import '../../data/datasources/compare_datasource.dart';
import '../../data/repositories/compare_repository_impl.dart';
import '../../domain/repositories/compare_repository.dart';
import '../../domain/usecases/fetch_related_wire_news_usecase.dart';

class CompareState {
  final NewsItem? report;
  final List<NewsItem> wireNews;
  final bool isLoading;
  final String? error;

  const CompareState({
    this.report,
    this.wireNews = const [],
    this.isLoading = false,
    this.error,
  });

  CompareState copyWith({
    NewsItem? report,
    List<NewsItem>? wireNews,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return CompareState(
      report: report ?? this.report,
      wireNews: wireNews ?? this.wireNews,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

final _compareDatasourceProvider = Provider((_) => CompareDatasourceImpl());

final compareRepositoryProvider = Provider<CompareRepository>(
  (ref) => CompareRepositoryImpl(ref.watch(_compareDatasourceProvider)),
);

final _fetchRelatedWireNewsUsecaseProvider = Provider(
  (ref) => FetchRelatedWireNewsUseCase(ref.watch(compareRepositoryProvider)),
);

final compareNotifierProvider = NotifierProvider<CompareNotifier, CompareState>(
  CompareNotifier.new,
);

class CompareNotifier extends Notifier<CompareState> {
  @override
  CompareState build() => const CompareState();

  Future<void> load(String reportId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(compareRepositoryProvider);
      final usecase = ref.read(_fetchRelatedWireNewsUsecaseProvider);
      final report = await repo.fetchReport(reportId);
      final wireNews = await usecase(
        description: '${report.title} ${report.body ?? ''}',
        category: report.category ?? 'other',
      );
      state = state.copyWith(
        report: report,
        wireNews: wireNews,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load compare data. Please try again.',
      );
    }
  }
}
