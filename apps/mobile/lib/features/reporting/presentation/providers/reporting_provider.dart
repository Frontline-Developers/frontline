import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/reporting_datasource.dart';
import '../../data/repositories/reporting_repository_impl.dart';
import '../../domain/entities/report.dart';

enum ReportingStatus { idle, loading, success, error }

class ReportingState {
  final ReportingStatus status;
  final String? submittedId;
  final String? error;
  const ReportingState({
    this.status = ReportingStatus.idle,
    this.submittedId,
    this.error,
  });

  ReportingState copyWith({
    ReportingStatus? status,
    Object? submittedId = _sentinel,
    Object? error = _sentinel,
  }) {
    return ReportingState(
      status: status ?? this.status,
      submittedId: submittedId == _sentinel
          ? this.submittedId
          : submittedId as String?,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

final _reportingDatasourceProvider = Provider((_) => ReportingDatasourceImpl());
final _reportingRepositoryProvider = Provider(
  (ref) => ReportingRepositoryImpl(ref.watch(_reportingDatasourceProvider)),
);

final reportingNotifierProvider =
    NotifierProvider<ReportingNotifier, ReportingState>(ReportingNotifier.new);

class ReportingNotifier extends Notifier<ReportingState> {
  @override
  ReportingState build() => const ReportingState();

  Future<void> submit(Report report) async {
    if (state.status == ReportingStatus.loading) return;
    state = state.copyWith(status: ReportingStatus.loading);
    try {
      final id = await ref
          .read(_reportingRepositoryProvider)
          .submitReport(report);
      state = state.copyWith(status: ReportingStatus.success, submittedId: id);
    } catch (e) {
      state = state.copyWith(
        status: ReportingStatus.error,
        error: e.toString(),
      );
    }
  }

  void reset() => state = const ReportingState();
}
