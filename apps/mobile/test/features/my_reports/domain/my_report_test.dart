import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/my_reports/domain/entities/my_report.dart';

void main() {
  group('MyReport', () {
    final report = MyReport(
      id: 'report-abc',
      category: 'combat',
      description: 'Artillery fire observed near river crossing',
      createdAt: DateTime(2026, 6, 4, 14, 0),
      status: 'pending',
    );

    test('stores all fields correctly', () {
      expect(report.id, 'report-abc');
      expect(report.category, 'combat');
      expect(report.description, 'Artillery fire observed near river crossing');
      expect(report.status, 'pending');
    });

    test('createdAt is stored', () {
      expect(report.createdAt, DateTime(2026, 6, 4, 14, 0));
    });

    test('can represent different statuses', () {
      for (final status in ['pending', 'confirmed', 'disputed', 'withdrawn']) {
        final r = MyReport(
          id: 'r',
          category: 'aid',
          description: 'desc',
          createdAt: DateTime.now(),
          status: status,
        );
        expect(r.status, status);
      }
    });

    test('can represent all categories', () {
      for (final cat in [
        'combat',
        'aid',
        'alert',
        'displaced',
        'infra',
        'other',
      ]) {
        final r = MyReport(
          id: 'r',
          category: cat,
          description: 'desc',
          createdAt: DateTime.now(),
          status: 'pending',
        );
        expect(r.category, cat);
      }
    });
  });
}
