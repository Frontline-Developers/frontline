import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/reporting/domain/entities/report.dart';
import 'package:frontline/features/reporting/domain/repositories/reporting_repository.dart';
import 'package:frontline/features/reporting/presentation/providers/reporting_provider.dart';

class _FakeRepo implements ReportingRepository {
  ReportDraft? lastSubmitted;
  bool throwOnSubmit = false;
  final List<int> progressTicks = [];

  @override
  Future<SubmitResult> submitReport(
    ReportDraft draft, {
    SubmitProgressCallback? onProgress,
  }) async {
    lastSubmitted = draft;
    if (throwOnSubmit) throw StateError('boom');
    for (var i = 1; i <= 4; i++) {
      onProgress?.call(i);
      progressTicks.add(i);
    }
    return const SubmitResult(
      reportId: 'r1',
      displayToken: 'a1b2-c3d4-e5f6-g7h8',
    );
  }
}

ProviderContainer _container(_FakeRepo repo) {
  return ProviderContainer(
    overrides: [reportingRepositoryProvider.overrideWithValue(repo)],
  );
}

void main() {
  group('ReportingNotifier — state transitions', () {
    test('initial state is describe stage with empty draft', () {
      final c = _container(_FakeRepo());
      addTearDown(c.dispose);
      final state = c.read(reportingNotifierProvider);
      expect(state.stage, ReportingStage.describe);
      expect(state.draft.description, '');
      expect(state.draft.category, isNull);
    });

    test('next() refuses to advance from describe when draft invalid', () {
      final c = _container(_FakeRepo());
      addTearDown(c.dispose);
      c.read(reportingNotifierProvider.notifier).next();
      expect(c.read(reportingNotifierProvider).stage, ReportingStage.describe);
    });

    test('next() advances describe -> location when draft is valid', () {
      final c = _container(_FakeRepo());
      addTearDown(c.dispose);
      final n = c.read(reportingNotifierProvider.notifier);
      n.updateDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
      );
      n.next();
      expect(c.read(reportingNotifierProvider).stage, ReportingStage.location);
    });

    test('back() moves to previous stage', () {
      final c = _container(_FakeRepo());
      addTearDown(c.dispose);
      final n = c.read(reportingNotifierProvider.notifier);
      n.updateDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
      );
      n.next();
      n.back();
      expect(c.read(reportingNotifierProvider).stage, ReportingStage.describe);
    });

    test('updateDraft merges into existing draft (sentinel pattern)', () {
      final c = _container(_FakeRepo());
      addTearDown(c.dispose);
      final n = c.read(reportingNotifierProvider.notifier);
      n.updateDraft(description: 'first');
      n.updateDraft(category: ReportCategory.aid);
      final state = c.read(reportingNotifierProvider);
      expect(state.draft.description, 'first');
      expect(state.draft.category, ReportCategory.aid);
    });
  });

  group('ReportingNotifier.submit', () {
    test(
      'happy path: describe -> ... -> processing -> success with token',
      () async {
        final repo = _FakeRepo();
        final c = _container(repo);
        addTearDown(c.dispose);
        final n = c.read(reportingNotifierProvider.notifier);
        n.updateDraft(
          description: 'a drone hit the substation',
          category: ReportCategory.combat,
          locationLabel: 'Kharkiv',
          lat: 50.024,
          lng: 36.229,
        );

        await n.submit();

        final state = c.read(reportingNotifierProvider);
        expect(state.stage, ReportingStage.success);
        expect(state.displayToken, 'a1b2-c3d4-e5f6-g7h8');
        expect(state.error, isNull);
        expect(repo.lastSubmitted, isNotNull);
        expect(repo.lastSubmitted!.description, 'a drone hit the substation');
      },
    );

    test(
      'processingStep advances through real datasource milestones',
      () async {
        final repo = _FakeRepo();
        final c = _container(repo);
        addTearDown(c.dispose);
        final n = c.read(reportingNotifierProvider.notifier);
        n.updateDraft(
          description: 'a drone hit the substation',
          category: ReportCategory.combat,
          locationLabel: 'Kharkiv',
          lat: 50.024,
          lng: 36.229,
        );
        await n.submit();
        // Repo tick history is what the notifier observed.
        expect(repo.progressTicks, [1, 2, 3, 4]);
      },
    );

    test(
      'error path: stays on evidence stage and exposes error message',
      () async {
        final repo = _FakeRepo()..throwOnSubmit = true;
        final c = _container(repo);
        addTearDown(c.dispose);
        final n = c.read(reportingNotifierProvider.notifier);
        n.updateDraft(
          description: 'a drone hit the substation',
          category: ReportCategory.combat,
          locationLabel: 'Kharkiv',
          lat: 50.024,
          lng: 36.229,
        );

        await n.submit();

        final state = c.read(reportingNotifierProvider);
        expect(state.stage, ReportingStage.evidence);
        expect(state.error, isNotNull);
        expect(state.displayToken, isNull);
      },
    );

    test(
      'reset() returns to initial describe stage with empty draft',
      () async {
        final c = _container(_FakeRepo());
        addTearDown(c.dispose);
        final n = c.read(reportingNotifierProvider.notifier);
        n.updateDraft(description: 'something', category: ReportCategory.aid);
        n.reset();
        final state = c.read(reportingNotifierProvider);
        expect(state.stage, ReportingStage.describe);
        expect(state.draft.description, '');
        expect(state.draft.category, isNull);
      },
    );
  });
}
