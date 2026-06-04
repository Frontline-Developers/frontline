import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/report.dart';

class ReportModel {
  final String? id;
  final String userId;
  final ReportCategory category;
  final String description;
  final String locationLabel;
  final double lat;
  final double lng;
  final String? geohash;
  final List<String> mediaUrls;
  final ReportStatus status;
  final int confirmCount;
  final int disputeCount;
  final bool isDisputed;
  final bool exifStripped;
  // SHA-256 of the display token — used by My Reports to query without auth UID.
  // Stored as a plain hex string; My Reports reads local tokens, hashes them,
  // and matches against this field.  Never stored in plain text.
  final String? tokenHash;

  const ReportModel({
    this.id,
    required this.userId,
    required this.category,
    required this.description,
    this.locationLabel = '',
    required this.lat,
    required this.lng,
    this.geohash,
    this.mediaUrls = const [],
    this.status = ReportStatus.pending,
    this.confirmCount = 0,
    this.disputeCount = 0,
    this.isDisputed = false,
    this.exifStripped = false,
    this.tokenHash,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'category': category.name,
    'description': description,
    'locationLabel': locationLabel,
    'location': GeoPoint(lat, lng),
    // geoflutterfire_plus expects a nested map {geohash, geopoint} at this
    // field, not a flat string — its internal query is orderBy('geohash.geohash').
    if (geohash != null)
      'geohash': {'geohash': geohash, 'geopoint': GeoPoint(lat, lng)},
    'mediaUrls': mediaUrls,
    'status': status.name,
    'confirmCount': confirmCount,
    'disputeCount': disputeCount,
    'isDisputed': isDisputed,
    'exifStripped': exifStripped,
    if (tokenHash != null) 'tokenHash': tokenHash,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
