import '../../domain/entities/report.dart';
import '../../domain/repositories/reporting_repository.dart';
import '../datasources/reporting_datasource.dart';

class ReportingRepositoryImpl implements ReportingRepository {
  final ReportingDatasource _datasource;
  ReportingRepositoryImpl(this._datasource);

  @override
  Future<String> submitReport(Report report) => _datasource.submitReport(report);
}
