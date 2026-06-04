import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/my_report_model.dart';
import '../../domain/entities/my_report.dart';

abstract class MyReportsDatasource {
  Stream<List<MyReport>> watchMyReports(String userId);
}

class MyReportsDatasourceImpl implements MyReportsDatasource {
  @override
  Stream<List<MyReport>> watchMyReports(String userId) {
    return FirebaseFirestore.instance
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MyReportModel.fromJson(d.id, d.data()).toEntity())
              .toList(),
        );
  }
}
