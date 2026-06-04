import '../entities/my_report.dart';

abstract class MyReportsRepository {
  Stream<List<MyReport>> watchMyReports();
  Future<void> deleteReport(String reportId, String token);
}
