import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/my_reports_datasource.dart';
import '../../data/repositories/my_reports_repository_impl.dart';
import '../../domain/entities/my_report.dart';

enum MyReportsFilter { all, verified, pending, disputed }

const _sentinel = Object();

class MyReportsState {
  final List<MyReport> reports;
  final bool isLoading;
  final String? error;
  final MyReportsFilter filter;
  final bool isDeleting;
  final bool isTruncated;

  const MyReportsState({
    this.reports = const [],
    this.isLoading = false,
    this.error,
    this.filter = MyReportsFilter.all,
    this.isDeleting = false,
    this.isTruncated = false,
  });

  List<MyReport> get filtered => switch (filter) {
    MyReportsFilter.all => reports,
    MyReportsFilter.verified =>
      reports.where((r) => r.status == 'verified').toList(),
    MyReportsFilter.pending =>
      reports.where((r) => r.status == 'pending').toList(),
    MyReportsFilter.disputed =>
      reports.where((r) => r.status == 'disputed').toList(),
  };

  int countFor(MyReportsFilter f) => switch (f) {
    MyReportsFilter.all => reports.length,
    MyReportsFilter.verified =>
      reports.where((r) => r.status == 'verified').length,
    MyReportsFilter.pending =>
      reports.where((r) => r.status == 'pending').length,
    MyReportsFilter.disputed =>
      reports.where((r) => r.status == 'disputed').length,
  };

  // Aggregate stats
  int get verifiedCount => countFor(MyReportsFilter.verified);
  int get totalConfirms => reports.fold(0, (s, r) => s + r.confirms);

  MyReportsState copyWith({
    List<MyReport>? reports,
    bool? isLoading,
    Object? error = _sentinel,
    MyReportsFilter? filter,
    bool? isDeleting,
    bool? isTruncated,
  }) => MyReportsState(
    reports: reports ?? this.reports,
    isLoading: isLoading ?? this.isLoading,
    error: error == _sentinel ? this.error : error as String?,
    filter: filter ?? this.filter,
    isDeleting: isDeleting ?? this.isDeleting,
    isTruncated: isTruncated ?? this.isTruncated,
  );
}

final _myReportsDatasourceProvider = Provider((_) => MyReportsDatasourceImpl());
final _myReportsRepositoryProvider = Provider(
  (ref) => MyReportsRepositoryImpl(ref.watch(_myReportsDatasourceProvider)),
);

final myReportsNotifierProvider =
    NotifierProvider<MyReportsNotifier, MyReportsState>(MyReportsNotifier.new);

class MyReportsNotifier extends Notifier<MyReportsState> {
  @override
  MyReportsState build() {
    ref
        .watch(_myReportsRepositoryProvider)
        .watchMyReports()
        .listen(
          (snapshot) => state = state.copyWith(
            reports: snapshot.reports,
            isTruncated: snapshot.isTruncated,
            isLoading: false,
          ),
          onError: (e) =>
              state = state.copyWith(error: e.toString(), isLoading: false),
        );
    return const MyReportsState(isLoading: true);
  }

  void setFilter(MyReportsFilter f) => state = state.copyWith(filter: f);

  Future<void> deleteReport(String reportId, String token) async {
    state = state.copyWith(isDeleting: true);
    try {
      await ref
          .read(_myReportsRepositoryProvider)
          .deleteReport(reportId, token);
      // Clear any previous error on success; stream emits the updated list.
      state = state.copyWith(error: null, isDeleting: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isDeleting: false);
    }
  }
}
