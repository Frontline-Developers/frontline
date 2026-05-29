import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/my_report.dart';

class MyReportModel {
  final String id;
  final String category;
  final String description;
  final DateTime createdAt;
  final String status;

  const MyReportModel({
    required this.id,
    required this.category,
    required this.description,
    required this.createdAt,
    required this.status,
  });

  factory MyReportModel.fromJson(String id, Map<String, dynamic> json) {
    final ts = json['createdAt'] as Timestamp;
    return MyReportModel(
      id: id,
      category: json['category'] as String,
      description: json['description'] as String,
      createdAt: ts.toDate(),
      status: json['status'] as String? ?? 'pending',
    );
  }

  MyReport toEntity() => MyReport(
    id: id,
    category: category,
    description: description,
    createdAt: createdAt,
    status: status,
  );
}
