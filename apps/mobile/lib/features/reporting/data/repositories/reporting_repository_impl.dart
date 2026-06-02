import '../../domain/entities/report.dart';
import '../../domain/repositories/reporting_repository.dart';
import '../datasources/reporting_datasource.dart';

class ReportingRepositoryImpl implements ReportingRepository {
  final ReportingDatasource _datasource;
  ReportingRepositoryImpl(this._datasource);

  @override
  Future<SubmitResult> submitReport(
    ReportDraft draft, {
    SubmitProgressCallback? onProgress,
  }) => _datasource.submitReport(draft, onProgress: onProgress);
}
