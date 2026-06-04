import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/reporting/data/datasources/reporting_datasource.dart';
import 'package:frontline/features/reporting/domain/entities/report.dart';

class _Calls {
  final List<Uint8List> exifInputs = [];
  final List<({double lat, double lng})> fuzzInputs = [];
  final List<({String path, Uint8List bytes})> uploads = [];
  final List<({String id, Map<String, dynamic> json})> writes = [];
  final List<String> savedTokens = [];
}

ReportingDatasourceImpl _buildDatasource({
  required _Calls calls,
  String? userId = 'uid-1',
  ({double lat, double lng}) fuzzedTo = (lat: 49.9, lng: 35.5),
  String reportId = 'report-123',
  String geohash = 'g-fuzz',
  String token = 'a1b2-c3d4-e5f6-g7h8',
}) {
  return ReportingDatasourceImpl(
    stripExif: (bytes) async {
      calls.exifInputs.add(bytes);
      return Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
    },
    fuzzLocation: (lat, lng) async {
      calls.fuzzInputs.add((lat: lat, lng: lng));
      return fuzzedTo;
    },
    uploadMedia: (path, bytes) async {
      calls.uploads.add((path: path, bytes: bytes));
      return 'https://storage.test/$path';
    },
    writeReport: (id, json) async {
      calls.writes.add((id: id, json: json));
    },
    currentUserId: () => userId,
    generateReportId: () => reportId,
    generateDisplayToken: () => token,
    geohashFor: (lat, lng) => geohash,
    saveToken: (t) async => calls.savedTokens.add(t),
  );
}

void main() {
  group('ReportingDatasourceImpl.submitReport', () {
    test('throws when user is not authenticated', () async {
      final calls = _Calls();
      final ds = _buildDatasource(calls: calls, userId: null);
      const draft = ReportDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
        locationLabel: 'Kharkiv',
        lat: 50.0,
        lng: 36.2,
      );
      expect(() => ds.submitReport(draft), throwsStateError);
    });

    test('calls fuzzLocation with raw user coords', () async {
      final calls = _Calls();
      final ds = _buildDatasource(calls: calls);
      const draft = ReportDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
        locationLabel: 'Kharkiv',
        lat: 50.024,
        lng: 36.229,
      );
      await ds.submitReport(draft);
      expect(calls.fuzzInputs, hasLength(1));
      expect(calls.fuzzInputs.single.lat, 50.024);
      expect(calls.fuzzInputs.single.lng, 36.229);
    });

    test(
      'writes Firestore doc with FUZZED location, never raw — privacy invariant',
      () async {
        final calls = _Calls();
        final ds = _buildDatasource(
          calls: calls,
          fuzzedTo: (lat: 49.999, lng: 35.888),
        );
        const draft = ReportDraft(
          description: 'a drone hit the substation',
          category: ReportCategory.combat,
          locationLabel: 'Kharkiv',
          lat: 50.024,
          lng: 36.229,
        );
        await ds.submitReport(draft);

        expect(calls.writes, hasLength(1));
        final json = calls.writes.single.json;
        final loc = json['location'] as GeoPoint;
        expect(loc.latitude, 49.999);
        expect(loc.longitude, 35.888);
        expect(loc.latitude, isNot(50.024));
        expect(loc.longitude, isNot(36.229));
      },
    );

    test('strips EXIF from every uploaded photo before upload', () async {
      final calls = _Calls();
      final ds = _buildDatasource(calls: calls);
      final draft = ReportDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
        locationLabel: 'Kharkiv',
        lat: 50.0,
        lng: 36.2,
        mediaBytes: [
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([4, 5, 6]),
        ],
      );
      await ds.submitReport(draft);
      expect(calls.exifInputs, hasLength(2));
      expect(calls.uploads, hasLength(2));
    });

    test('uploads media under reports/{uid}/{reportId}/ path', () async {
      final calls = _Calls();
      final ds = _buildDatasource(
        calls: calls,
        userId: 'uid-1',
        reportId: 'rep-42',
      );
      final draft = ReportDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
        locationLabel: 'Kharkiv',
        lat: 50.0,
        lng: 36.2,
        mediaBytes: [
          Uint8List.fromList([1]),
        ],
      );
      await ds.submitReport(draft);
      expect(calls.uploads.single.path, startsWith('reports/uid-1/rep-42/'));
    });

    test(
      'writes report doc with exifStripped: true and status: pending',
      () async {
        final calls = _Calls();
        final ds = _buildDatasource(calls: calls);
        const draft = ReportDraft(
          description: 'a drone hit the substation',
          category: ReportCategory.combat,
          locationLabel: 'Kharkiv',
          lat: 50.0,
          lng: 36.2,
        );
        await ds.submitReport(draft);
        final json = calls.writes.single.json;
        expect(json['exifStripped'], true);
        expect(json['status'], 'pending');
        expect(json['confirmCount'], 0);
        expect(json['disputeCount'], 0);
        expect(json['isDisputed'], false);
      },
    );

    test('writes report doc with userId from auth', () async {
      final calls = _Calls();
      final ds = _buildDatasource(calls: calls, userId: 'auth-xyz');
      const draft = ReportDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
        locationLabel: 'Kharkiv',
        lat: 50.0,
        lng: 36.2,
      );
      await ds.submitReport(draft);
      expect(calls.writes.single.json['userId'], 'auth-xyz');
    });

    test('returns reportId and a token matching the design format', () async {
      final calls = _Calls();
      final ds = _buildDatasource(
        calls: calls,
        reportId: 'rep-99',
        token: 'abcd-1234-efgh-5678',
      );
      const draft = ReportDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
        locationLabel: 'Kharkiv',
        lat: 50.0,
        lng: 36.2,
      );
      final result = await ds.submitReport(draft);
      expect(result.reportId, 'rep-99');
      expect(result.displayToken, 'abcd-1234-efgh-5678');
      expect(
        RegExp(r'^[a-z0-9]{4}(-[a-z0-9]{4}){3}$').hasMatch(result.displayToken),
        true,
      );
    });

    test('throws when media exceeds maxPhotos', () async {
      final calls = _Calls();
      final ds = _buildDatasource(calls: calls);
      final draft = ReportDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
        locationLabel: 'Kharkiv',
        lat: 50.0,
        lng: 36.2,
        mediaBytes: List.generate(
          ReportDraft.maxPhotos + 1,
          (_) => Uint8List.fromList([1, 2, 3]),
        ),
      );
      expect(() => ds.submitReport(draft), throwsArgumentError);
    });

    test(
      'writes tokenHash (sha-256 of display token) to Firestore — never plain token',
      () async {
        const token = 'abcd-1234-efgh-5678';
        final expectedHash = sha256.convert(utf8.encode(token)).toString();
        final calls = _Calls();
        final ds = _buildDatasource(calls: calls, token: token);
        const draft = ReportDraft(
          description: 'a drone hit the substation',
          category: ReportCategory.combat,
          locationLabel: 'Kharkiv',
          lat: 50.0,
          lng: 36.2,
        );
        await ds.submitReport(draft);
        final json = calls.writes.single.json;
        expect(
          json['tokenHash'],
          expectedHash,
          reason: 'tokenHash must be SHA-256 hex, not the plain token',
        );
        expect(json.containsKey('tokenHash'), true);
        expect(
          json['tokenHash'],
          isNot(equals(token)),
          reason: 'plain token must never be written to Firestore',
        );
      },
    );

    test('saves plain display token to local storage after write', () async {
      const token = 'abcd-1234-efgh-5678';
      final calls = _Calls();
      final ds = _buildDatasource(calls: calls, token: token);
      const draft = ReportDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
        locationLabel: 'Kharkiv',
        lat: 50.0,
        lng: 36.2,
      );
      await ds.submitReport(draft);
      expect(calls.savedTokens, contains(token));
    });

    test('saves token BEFORE Firestore write to avoid orphaned reports', () async {
      final order = <String>[];
      final ds = ReportingDatasourceImpl(
        stripExif: (b) async => b,
        fuzzLocation: (lat, lng) async => (lat: lat, lng: lng),
        uploadMedia: (p, b) async => 'https://storage.test/$p',
        writeReport: (id, json) async => order.add('write'),
        currentUserId: () => 'uid-1',
        generateReportId: () => 'rep-1',
        generateDisplayToken: () => 'abcd-1234-efgh-5678',
        geohashFor: (lat, lng) => 'g123',
        saveToken: (t) async => order.add('save'),
      );
      const draft = ReportDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
        locationLabel: 'Kharkiv',
        lat: 50.0,
        lng: 36.2,
      );
      await ds.submitReport(draft);
      expect(order, [
        'save',
        'write',
      ], reason: 'token must be saved before Firestore write — a stale local token is harmless, an orphaned Firestore doc is not');
    });

    test('includes geohash computed from fuzzed coords', () async {
      final calls = _Calls();
      final ds = _buildDatasource(calls: calls, geohash: 'gbsuv');
      const draft = ReportDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
        locationLabel: 'Kharkiv',
        lat: 50.0,
        lng: 36.2,
      );
      await ds.submitReport(draft);
      expect(calls.writes.single.json['geohash'], 'gbsuv');
    });
  });

  group('generateDefaultDisplayToken', () {
    test('produces xxxx-xxxx-xxxx-xxxx base36 lowercase', () {
      final tok = generateDefaultDisplayToken();
      expect(
        RegExp(r'^[a-z0-9]{4}(-[a-z0-9]{4}){3}$').hasMatch(tok),
        true,
        reason: 'got "$tok"',
      );
    });

    test('produces different tokens on repeated calls', () {
      final tokens = {
        for (var i = 0; i < 20; i++) generateDefaultDisplayToken(),
      };
      expect(tokens.length, greaterThan(15));
    });
  });
}
