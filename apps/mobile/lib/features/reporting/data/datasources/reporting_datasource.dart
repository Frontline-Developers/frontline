import '../../domain/entities/report.dart';

abstract class ReportingDatasource {
  Future<String> submitReport(Report report);
}

// TODO: implement — call `fuzzReportLocation` CF, upload media to Storage, write to Firestore
class ReportingDatasourceImpl implements ReportingDatasource {
  @override
  Future<String> submitReport(Report report) async {
    throw UnimplementedError('submitReport not yet implemented');
  }
}
