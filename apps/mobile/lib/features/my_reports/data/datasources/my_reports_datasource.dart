import '../../domain/entities/my_report.dart';

abstract class MyReportsDatasource {
  Stream<List<MyReport>> watchMyReports(String userId);
}

// TODO: implement — query Firestore `reports` where userId == uid
class MyReportsDatasourceImpl implements MyReportsDatasource {
  @override
  Stream<List<MyReport>> watchMyReports(String userId) => Stream.value([]);
}
