import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/map_report.dart';

class MapReportModel {
  final String id;
  final double lat;
  final double lng;
  final String category;
  final String title;
  final String locationLabel;
  final String status;
  final DateTime createdAt;

  const MapReportModel({
    required this.id,
    required this.lat,
    required this.lng,
    required this.category,
    required this.title,
    required this.locationLabel,
    required this.status,
    required this.createdAt,
  });

  factory MapReportModel.fromJson(String id, Map<String, dynamic> json) {
    final ts = json['createdAt'] as Timestamp?;
    final gp = json['location'] as GeoPoint;
    return MapReportModel(
      id: id,
      lat: gp.latitude,
      lng: gp.longitude,
      category: json['category'] as String? ?? 'other',
      // Firestore schema uses 'description'; fallback to 'title' for mock data.
      title: json['description'] as String? ?? json['title'] as String? ?? '',
      locationLabel: json['locationLabel'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: ts?.toDate() ?? DateTime.now(),
    );
  }

  MapReport toEntity() => MapReport(
    id: id,
    lat: lat,
    lng: lng,
    category: category,
    title: title,
    locationLabel: locationLabel,
    status: status,
    createdAt: createdAt,
  );
}
