import '../entities/report.dart';

abstract class ReportingRepository {
  Future<String> submitReport(Report report);
}
