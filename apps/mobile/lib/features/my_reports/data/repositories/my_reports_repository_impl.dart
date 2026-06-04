import '../../domain/entities/my_report.dart';
import '../../domain/repositories/my_reports_repository.dart';
import '../datasources/my_reports_datasource.dart';

class MyReportsRepositoryImpl implements MyReportsRepository {
  final MyReportsDatasource _datasource;
  MyReportsRepositoryImpl(this._datasource);

  @override
  Stream<({List<MyReport> reports, bool isTruncated})> watchMyReports() =>
      _datasource.watchMyReports();

  @override
  Future<void> deleteReport(String reportId, String token) =>
      _datasource.deleteReport(reportId, token);
}
