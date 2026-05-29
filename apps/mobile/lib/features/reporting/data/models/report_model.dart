import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/report.dart';

class ReportModel {
  final String? id;
  final String category;
  final String description;
  final double lat;
  final double lng;
  final List<String> mediaUrls;
  final DateTime? createdAt;

  const ReportModel({
    this.id,
    required this.category,
    required this.description,
    required this.lat,
    required this.lng,
    this.mediaUrls = const [],
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'description': description,
    'location': GeoPoint(lat, lng),
    'mediaUrls': mediaUrls,
    'createdAt': FieldValue.serverTimestamp(),
  };

  Report toEntity() => Report(
    id: id,
    category: category,
    description: description,
    lat: lat,
    lng: lng,
    mediaUrls: mediaUrls,
    createdAt: createdAt,
  );

  static ReportModel fromEntity(Report report) => ReportModel(
    id: report.id,
    category: report.category,
    description: report.description,
    lat: report.lat,
    lng: report.lng,
    mediaUrls: report.mediaUrls,
    createdAt: report.createdAt,
  );
}
