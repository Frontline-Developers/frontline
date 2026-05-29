import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/my_reports_datasource.dart';
import '../../data/repositories/my_reports_repository_impl.dart';
import '../../domain/entities/my_report.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class MyReportsState {
  final List<MyReport> reports;
  final bool isLoading;
  final String? error;
  const MyReportsState({this.reports = const [], this.isLoading = false, this.error});
}

final _myReportsDatasourceProvider = Provider((_) => MyReportsDatasourceImpl());
final _myReportsRepositoryProvider = Provider(
  (ref) => MyReportsRepositoryImpl(ref.watch(_myReportsDatasourceProvider)),
);

final myReportsNotifierProvider =
    NotifierProvider<MyReportsNotifier, MyReportsState>(MyReportsNotifier.new);

class MyReportsNotifier extends Notifier<MyReportsState> {
  @override
  MyReportsState build() {
    final authState = ref.watch(authNotifierProvider);
    final uid = authState.user?.uid;
    if (uid == null) return const MyReportsState();
    ref.watch(_myReportsRepositoryProvider).watchMyReports(uid).listen(
      (reports) => state = MyReportsState(reports: reports),
      onError: (e) => state = MyReportsState(error: e.toString()),
    );
    return const MyReportsState(isLoading: true);
  }
}
