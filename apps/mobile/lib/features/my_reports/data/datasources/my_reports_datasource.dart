import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/my_report.dart';
import '../models/my_report_model.dart';

abstract class MyReportsDatasource {
  Stream<List<MyReport>> watchMyReports();
  Future<void> deleteReport(String reportId, String token);
}

// Storage key for the JSON list of local tokens.
const _kTokensKey = 'frontline_report_tokens';

class MyReportsDatasourceImpl implements MyReportsDatasource {
  final FirebaseFirestore _db;
  final FlutterSecureStorage _storage;

  MyReportsDatasourceImpl({
    FirebaseFirestore? db,
    FlutterSecureStorage? storage,
  }) : _db = db ?? FirebaseFirestore.instance,
       _storage = storage ?? const FlutterSecureStorage();

  // ── Token helpers ──────────────────────────────────────────────────────────

  Future<List<String>> _readTokens() async {
    final raw = await _storage.read(key: _kTokensKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<String>();
  }

  Future<void> _removeToken(String token) async {
    final tokens = await _readTokens();
    tokens.remove(token);
    await _storage.write(key: _kTokensKey, value: jsonEncode(tokens));
  }

  static String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  // ── Datasource methods ─────────────────────────────────────────────────────

  @override
  Stream<List<MyReport>> watchMyReports() async* {
    final tokens = await _readTokens();
    if (tokens.isEmpty) {
      yield [];
      return;
    }

    final hashToToken = {for (final t in tokens) _sha256(t): t};
    final hashes = hashToToken.keys.toList();

    // Firestore whereIn is capped at 30; take first batch (typical user has < 30 reports).
    final batch = hashes.take(30).toList();

    yield* _db
        .collection('reports')
        .where('tokenHash', whereIn: batch)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) {
                final hash = d.data()['tokenHash'] as String? ?? '';
                final localToken = hashToToken[hash] ?? '';
                return MyReportModel.fromFirestore(
                  d.id,
                  d.data(),
                  localToken,
                ).toEntity();
              })
              .where((r) => r.status != 'deleted')
              .toList(),
        );
  }

  @override
  Future<void> deleteReport(String reportId, String token) async {
    await _db.collection('reports').doc(reportId).update({
      'status': 'deleted',
      'tokenHash': FieldValue.delete(),
    });
    await _removeToken(token);
  }
}
