import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/my_report.dart';
import '../models/my_report_model.dart';

// ── Typedef seams (injectable for testing) ────────────────────────────────────

/// Reads the list of locally-stored plain display tokens.
typedef TokensReader = Future<List<String>> Function();

/// Removes a single plain token from local storage after delete.
typedef TokenRemover = Future<void> Function(String token);

/// Streams reports whose tokenHash matches any of the provided hashes.
/// Receives [hashToToken] so each document's tokenHash can be resolved back
/// to the plain display token without a second storage read.
typedef ReportsWatcher =
    Stream<List<MyReport>> Function(
      List<String> tokenHashes,
      Map<String, String> hashToToken,
    );

/// Soft-deletes a report: sets status='deleted' and removes tokenHash.
typedef ReportSoftDeleter = Future<void> Function(String reportId);

// ── Interface ─────────────────────────────────────────────────────────────────

abstract class MyReportsDatasource {
  Stream<({List<MyReport> reports, bool isTruncated})> watchMyReports();
  Future<void> deleteReport(String reportId, String token);
}

// ── Implementation ────────────────────────────────────────────────────────────

class MyReportsDatasourceImpl implements MyReportsDatasource {
  final TokensReader _readTokens;
  final TokenRemover _removeToken;
  final ReportsWatcher _watchReports;
  final ReportSoftDeleter _softDelete;

  MyReportsDatasourceImpl({
    TokensReader? readTokens,
    TokenRemover? removeToken,
    ReportsWatcher? watchReports,
    ReportSoftDeleter? softDelete,
  }) : _readTokens = readTokens ?? _defaultReadTokens,
       _removeToken = removeToken ?? _defaultRemoveToken,
       _watchReports = watchReports ?? _defaultWatchReports,
       _softDelete = softDelete ?? _defaultSoftDelete;

  @override
  Stream<({List<MyReport> reports, bool isTruncated})> watchMyReports() async* {
    final tokens = await _readTokens();
    if (tokens.isEmpty) {
      yield (reports: [], isTruncated: false);
      return;
    }
    // Compute SHA-256 hash for each token — matches the tokenHash field written
    // to Firestore by ReportingDatasource at submission time.
    final hashToToken = {for (final t in tokens) _sha256(t): t};
    // Firestore whereIn is limited to 30 items. Expose the truncation flag so
    // the UI can warn users who have submitted more than 30 reports.
    final isTruncated = hashToToken.length > 30;
    final hashes = hashToToken.keys.take(30).toList();
    yield* _watchReports(hashes, hashToToken).map(
      (reports) => (
        reports: reports.where((r) => r.status != 'deleted').toList(),
        isTruncated: isTruncated,
      ),
    );
  }

  @override
  Future<void> deleteReport(String reportId, String token) async {
    // Soft-delete on Firestore first, then remove the local token.
    // Business rule: only disputed reports are deletable — enforced by
    // Firestore rules; UI never shows the trash icon on verified/pending.
    await _softDelete(reportId);
    await _removeToken(token);
  }

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}

// ── Default seam implementations (real Firebase + SecureStorage) ──────────────

Future<List<String>> _defaultReadTokens() async {
  const storage = FlutterSecureStorage();
  final raw = await storage.read(key: kReportTokensStorageKey);
  if (raw == null) return [];
  return (jsonDecode(raw) as List).cast<String>();
}

Future<void> _defaultRemoveToken(String token) async {
  const storage = FlutterSecureStorage();
  final raw = await storage.read(key: kReportTokensStorageKey);
  final tokens = raw != null
      ? (jsonDecode(raw) as List).cast<String>()
      : <String>[];
  if (tokens.remove(token)) {
    await storage.write(
      key: kReportTokensStorageKey,
      value: jsonEncode(tokens),
    );
  }
}

Stream<List<MyReport>> _defaultWatchReports(
  List<String> tokenHashes,
  Map<String, String> hashToToken,
) {
  return FirebaseFirestore.instance
      .collection('reports')
      // whereIn only — no orderBy to avoid requiring a composite index.
      .where('tokenHash', whereIn: tokenHashes)
      .snapshots()
      .map((snap) {
        final reports = snap.docs.map((d) {
          final docHash = d.data()['tokenHash'] as String? ?? '';
          final localToken = hashToToken[docHash] ?? '';
          return MyReportModel.fromFirestore(
            d.id,
            d.data(),
            localToken,
          ).toEntity();
        }).toList();
        // Sort client-side: newest first.
        reports.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
        return reports;
      });
}

Future<void> _defaultSoftDelete(String reportId) async {
  await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
    'status': 'deleted',
    'tokenHash': FieldValue.delete(),
  });
}
