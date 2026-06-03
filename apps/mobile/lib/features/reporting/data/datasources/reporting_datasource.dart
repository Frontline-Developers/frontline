import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../../domain/entities/report.dart';
import '../../domain/repositories/reporting_repository.dart';
import '../models/report_model.dart';

typedef ExifStripper = Future<Uint8List> Function(Uint8List bytes);
typedef LocationFuzzer =
    Future<({double lat, double lng})> Function(double lat, double lng);
typedef MediaUploader = Future<String> Function(String path, Uint8List bytes);
typedef ReportWriter =
    Future<void> Function(String id, Map<String, dynamic> json);
typedef CurrentUserIdProvider = String? Function();
typedef ReportIdGenerator = String Function();
typedef DisplayTokenGenerator = String Function();
typedef GeohashCalculator = String Function(double lat, double lng);

abstract class ReportingDatasource {
  Future<SubmitResult> submitReport(
    ReportDraft draft, {
    SubmitProgressCallback? onProgress,
  });
}

class ReportingDatasourceImpl implements ReportingDatasource {
  final ExifStripper _stripExif;
  final LocationFuzzer _fuzzLocation;
  final MediaUploader _uploadMedia;
  final ReportWriter _writeReport;
  final CurrentUserIdProvider _currentUserId;
  final ReportIdGenerator _generateReportId;
  final DisplayTokenGenerator _generateDisplayToken;
  final GeohashCalculator _geohashFor;

  ReportingDatasourceImpl({
    ExifStripper? stripExif,
    LocationFuzzer? fuzzLocation,
    MediaUploader? uploadMedia,
    ReportWriter? writeReport,
    CurrentUserIdProvider? currentUserId,
    ReportIdGenerator? generateReportId,
    DisplayTokenGenerator? generateDisplayToken,
    GeohashCalculator? geohashFor,
  }) : _stripExif = stripExif ?? _defaultStripExif,
       _fuzzLocation = fuzzLocation ?? _defaultFuzzLocation,
       _uploadMedia = uploadMedia ?? _defaultUploadMedia,
       _writeReport = writeReport ?? _defaultWriteReport,
       _currentUserId = currentUserId ?? _defaultCurrentUserId,
       _generateReportId = generateReportId ?? _defaultGenerateReportId,
       _generateDisplayToken =
           generateDisplayToken ?? generateDefaultDisplayToken,
       _geohashFor = geohashFor ?? _defaultGeohash;

  @override
  Future<SubmitResult> submitReport(
    ReportDraft draft, {
    SubmitProgressCallback? onProgress,
  }) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError('No authenticated user — cannot submit report.');
    }
    if (draft.lat == null || draft.lng == null || draft.category == null) {
      throw ArgumentError('Draft is missing required fields.');
    }
    if (draft.mediaBytes.length > ReportDraft.maxPhotos) {
      throw ArgumentError(
        'Too many photos: maximum ${ReportDraft.maxPhotos} allowed.',
      );
    }

    final reportId = _generateReportId();

    // Milestone 1: strip EXIF on every photo in parallel.
    final strippedMedia = await Future.wait(draft.mediaBytes.map(_stripExif));
    onProgress?.call(1);

    // Milestone 2: fuzz GPS server-side. Privacy invariant — raw coords
    // never reach Firestore.
    final fuzzed = await _fuzzLocation(draft.lat!, draft.lng!);
    onProgress?.call(2);

    final geohash = _geohashFor(fuzzed.lat, fuzzed.lng);

    // Milestone 3: parallel uploads. Storage path is scoped to {userId}/{reportId}.
    // We don't store the request IP (Firebase logs it transiently at the edge —
    // see project brief §5: "your IP is never stored in your report").
    final mediaUrls = await Future.wait([
      for (var i = 0; i < strippedMedia.length; i++)
        _uploadMedia(
          'reports/$userId/$reportId/photo_$i.jpg',
          strippedMedia[i],
        ),
    ]);
    onProgress?.call(3);

    final model = ReportModel(
      id: reportId,
      userId: userId,
      category: draft.category!,
      description: draft.description.trim(),
      lat: fuzzed.lat,
      lng: fuzzed.lng,
      geohash: geohash,
      mediaUrls: mediaUrls,
      exifStripped: true,
    );

    // Milestone 4: write the report and generate the user's tracking token.
    await _writeReport(reportId, model.toJson());
    final token = _generateDisplayToken();
    onProgress?.call(4);

    return SubmitResult(reportId: reportId, displayToken: token);
  }
}

// ── Default seam implementations (real Firebase) ────────────────────────────

Future<Uint8List> _defaultStripExif(Uint8List bytes) async {
  final out = await FlutterImageCompress.compressWithList(
    bytes,
    quality: 88,
    keepExif: false,
  );
  return out;
}

Future<({double lat, double lng})> _defaultFuzzLocation(
  double lat,
  double lng,
) async {
  final callable = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  ).httpsCallable('fuzzReportLocation');
  final res = await callable.call(<String, dynamic>{'lat': lat, 'lng': lng});
  final data = Map<String, dynamic>.from(res.data as Map);
  return (
    lat: (data['lat'] as num).toDouble(),
    lng: (data['lng'] as num).toDouble(),
  );
}

Future<String> _defaultUploadMedia(String path, Uint8List bytes) async {
  final ref = FirebaseStorage.instance.ref(path);
  await ref.putData(bytes);
  return ref.getDownloadURL();
}

Future<void> _defaultWriteReport(String id, Map<String, dynamic> json) async {
  await FirebaseFirestore.instance.collection('reports').doc(id).set(json);
}

String? _defaultCurrentUserId() => FirebaseAuth.instance.currentUser?.uid;

String _defaultGenerateReportId() =>
    FirebaseFirestore.instance.collection('reports').doc().id;

String _defaultGeohash(double lat, double lng) =>
    GeoFirePoint(GeoPoint(lat, lng)).geohash;

// ── Public token generator (exposed for tests + UI) ─────────────────────────

const _tokenAlphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

String generateDefaultDisplayToken() {
  final r = Random.secure();
  String group() => List.generate(
    4,
    (_) => _tokenAlphabet[r.nextInt(_tokenAlphabet.length)],
  ).join();
  return '${group()}-${group()}-${group()}-${group()}';
}
