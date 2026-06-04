import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/my_reports/data/datasources/my_reports_datasource.dart';
import 'package:frontline/features/my_reports/domain/entities/my_report.dart';

// ── In-memory token store helpers ─────────────────────────────────────────────

List<String> _store = [];

Future<List<String>> _fakeRead() async => List.of(_store);

Future<void> _fakeRemove(String t) async {
  _store.remove(t);
}

String _hash(String t) => sha256.convert(utf8.encode(t)).toString();

// ── Fake Firestore watcher ────────────────────────────────────────────────────

MyReport _makeReport({
  String id = 'rpt-1',
  String token = '',
  String status = 'pending',
}) => MyReport(
  id: id,
  title: 'Strike on substation',
  body: 'Heard the impact at 03:42.',
  category: 'infra',
  location: 'Kharkiv',
  status: status,
  token: token,
  submittedAt: DateTime(2025, 3, 18, 3, 46),
);

MyReportsDatasourceImpl _buildDs({
  List<String>? initialTokens,
  Stream<List<MyReport>> Function(List<String>, Map<String, String>)? watcher,
  List<String>? deletedIds,
}) {
  _store = List.of(initialTokens ?? []);
  final deleted = deletedIds ?? [];

  return MyReportsDatasourceImpl(
    readTokens: _fakeRead,
    removeToken: _fakeRemove,
    watchReports:
        watcher ??
        (hashes, hashToToken) =>
            Stream.value(hashes.map((h) => _makeReport(id: 'rpt-$h')).toList()),
    softDelete: (id) async => deleted.add(id),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('MyReportsDatasourceImpl.watchMyReports', () {
    test('emits empty reports and isTruncated=false when no tokens are stored',
        () async {
      final ds = _buildDs(initialTokens: []);
      final result = await ds.watchMyReports().first;
      expect(result.reports, isEmpty);
      expect(result.isTruncated, false);
    });

    test('queries Firestore with SHA-256 hashes of stored tokens', () async {
      const token = 'abcd-1234-efgh-5678';
      final expectedHash = _hash(token);
      List<String>? capturedHashes;

      final ds = _buildDs(
        initialTokens: [token],
        watcher: (hashes, hashToToken) {
          capturedHashes = hashes;
          return Stream.value([]);
        },
      );

      await ds.watchMyReports().first;
      expect(capturedHashes, contains(expectedHash));
    });

    test('never passes plain token to Firestore watcher', () async {
      const token = 'abcd-1234-efgh-5678';
      List<String>? capturedHashes;

      final ds = _buildDs(
        initialTokens: [token],
        watcher: (hashes, hashToToken) {
          capturedHashes = hashes;
          return Stream.value([]);
        },
      );

      await ds.watchMyReports().first;
      expect(capturedHashes, isNot(contains(token)));
    });

    test('filters out soft-deleted reports from stream', () async {
      const token = 'abcd-1234-efgh-5678';
      final ds = _buildDs(
        initialTokens: [token],
        watcher: (hashes, hashToToken) => Stream.value([
          _makeReport(status: 'deleted'),
          _makeReport(id: 'rpt-2', status: 'pending'),
        ]),
      );

      final result = await ds.watchMyReports().first;
      expect(result.reports.length, 1);
      expect(result.reports.single.id, 'rpt-2');
    });

    test('caps Firestore whereIn at 30 hashes', () async {
      final manyTokens = List.generate(35, (i) => 'tok-$i-aaaa-bbbb');
      List<String>? capturedHashes;

      final ds = _buildDs(
        initialTokens: manyTokens,
        watcher: (hashes, hashToToken) {
          capturedHashes = hashes;
          return Stream.value([]);
        },
      );

      await ds.watchMyReports().first;
      expect(capturedHashes!.length, lessThanOrEqualTo(30));
    });

    test('exposes isTruncated=true when token count exceeds 30', () async {
      final manyTokens = List.generate(35, (i) => 'tok-$i-aaaa-bbbb');

      final ds = _buildDs(
        initialTokens: manyTokens,
        watcher: (hashes, hashToToken) => Stream.value([]),
      );

      final result = await ds.watchMyReports().first;
      expect(result.isTruncated, true);
    });

    test('isTruncated=false when token count is exactly 30', () async {
      final tokens = List.generate(30, (i) => 'tok-$i-aaaa-bbbb');

      final ds = _buildDs(
        initialTokens: tokens,
        watcher: (hashes, hashToToken) => Stream.value([]),
      );

      final result = await ds.watchMyReports().first;
      expect(result.isTruncated, false);
    });
  });

  group('MyReportsDatasourceImpl.deleteReport', () {
    test('calls soft-deleter with correct reportId', () async {
      final deleted = <String>[];
      const token = 'abcd-1234-efgh-5678';
      _store = [token];

      final ds = MyReportsDatasourceImpl(
        readTokens: _fakeRead,
        removeToken: _fakeRemove,
        watchReports: (hashes, map) => Stream.value([]),
        softDelete: (id) async => deleted.add(id),
      );

      await ds.deleteReport('rpt-1', token);
      expect(deleted, contains('rpt-1'));
    });

    test('removes token from local storage after delete', () async {
      final deleted = <String>[];
      const token = 'abcd-1234-efgh-5678';
      _store = [token, 'other-tok-xxxx'];

      final ds = MyReportsDatasourceImpl(
        readTokens: _fakeRead,
        removeToken: _fakeRemove,
        watchReports: (hashes, map) => Stream.value([]),
        softDelete: (id) async => deleted.add(id),
      );

      await ds.deleteReport('rpt-1', token);
      expect(_store, isNot(contains(token)));
      expect(_store, contains('other-tok-xxxx'));
    });

    test('does not remove other tokens when deleting one report', () async {
      const token1 = 'aaaa-1111-aaaa-1111';
      const token2 = 'bbbb-2222-bbbb-2222';
      _store = [token1, token2];

      final ds = MyReportsDatasourceImpl(
        readTokens: _fakeRead,
        removeToken: _fakeRemove,
        watchReports: (hashes, map) => Stream.value([]),
        softDelete: (_) async {},
      );

      await ds.deleteReport('rpt-1', token1);
      expect(_store, isNot(contains(token1)));
      expect(_store, contains(token2));
    });
  });
}
