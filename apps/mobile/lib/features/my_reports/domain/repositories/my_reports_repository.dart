import '../entities/my_report.dart';

abstract class MyReportsRepository {
  Stream<List<MyReport>> watchMyReports(String userId);
}
