import 'dart:typed_data';

enum ReportCategory { combat, aid, alert, displaced, infra, other }

enum ReportStatus { pending, confirmed, disputed, withdrawn }

class Report {
  final String? id;
  final String? userId;
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
  final int systemConfirms;
  final int systemDisputes;
  final double totalEffectiveVolume;
  final double confidenceRatio;
  final DateTime? createdAt;

  const Report({
    this.id,
    this.userId,
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
    this.systemConfirms = 0,
    this.systemDisputes = 0,
    this.totalEffectiveVolume = 0,
    this.confidenceRatio = 0,
    this.createdAt,
  });
}

class ReportDraft {
  final String description;
  final ReportCategory? category;
  final String locationLabel;
  final double? lat;
  final double? lng;
  final List<Uint8List> mediaBytes;
  final String? timeObserved;

  const ReportDraft({
    this.description = '',
    this.category,
    this.locationLabel = '',
    this.lat,
    this.lng,
    this.mediaBytes = const [],
    this.timeObserved,
  });

  static const int minDescriptionLength = 10;

  bool get isDescribeValid =>
      description.trim().length >= minDescriptionLength && category != null;

  bool get isLocationValid => lat != null && lng != null;

  static const int maxPhotos = 5;

  bool get isEvidenceValid =>
      mediaBytes.isNotEmpty && mediaBytes.length <= maxPhotos;

  ReportDraft copyWith({
    String? description,
    Object? category = _sentinel,
    String? locationLabel,
    Object? lat = _sentinel,
    Object? lng = _sentinel,
    List<Uint8List>? mediaBytes,
    Object? timeObserved = _sentinel,
  }) {
    return ReportDraft(
      description: description ?? this.description,
      category: category == _sentinel
          ? this.category
          : category as ReportCategory?,
      locationLabel: locationLabel ?? this.locationLabel,
      lat: lat == _sentinel ? this.lat : lat as double?,
      lng: lng == _sentinel ? this.lng : lng as double?,
      mediaBytes: mediaBytes ?? this.mediaBytes,
      timeObserved: timeObserved == _sentinel
          ? this.timeObserved
          : timeObserved as String?,
    );
  }
}

const _sentinel = Object();

class SubmitResult {
  final String reportId;
  final String displayToken;
  const SubmitResult({required this.reportId, required this.displayToken});
}
