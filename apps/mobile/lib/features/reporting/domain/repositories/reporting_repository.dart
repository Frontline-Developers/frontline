import '../entities/report.dart';

typedef SubmitProgressCallback = void Function(int milestone);

abstract class ReportingRepository {
  Future<SubmitResult> submitReport(
    ReportDraft draft, {
    SubmitProgressCallback? onProgress,
  });
}
