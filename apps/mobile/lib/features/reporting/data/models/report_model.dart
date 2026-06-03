import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/report.dart';

class ReportModel {
  final String? id;
  final String userId;
  final ReportCategory category;
  final String description;
  final double lat;
  final double lng;
  final String? geohash;
  final List<String> mediaUrls;
  final ReportStatus status;
  final int confirmCount;
  final int disputeCount;
  final bool isDisputed;
  final bool exifStripped;

  const ReportModel({
    this.id,
    required this.userId,
    required this.category,
    required this.description,
    required this.lat,
    required this.lng,
    this.geohash,
    this.mediaUrls = const [],
    this.status = ReportStatus.pending,
    this.confirmCount = 0,
    this.disputeCount = 0,
    this.isDisputed = false,
    this.exifStripped = false,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'category': category.name,
    'description': description,
    'location': GeoPoint(lat, lng),
    if (geohash != null) 'geohash': geohash,
    'mediaUrls': mediaUrls,
    'status': status.name,
    'confirmCount': confirmCount,
    'disputeCount': disputeCount,
    'isDisputed': isDisputed,
    'exifStripped': exifStripped,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
