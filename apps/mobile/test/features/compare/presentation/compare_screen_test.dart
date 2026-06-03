import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/compare/domain/entities/event_cluster.dart';
import 'package:frontline/features/compare/presentation/providers/compare_provider.dart';
import 'package:frontline/features/compare/presentation/screens/compare_screen.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';

class _FakeCompareNotifier extends CompareNotifier {
  final CompareState _initial;
  _FakeCompareNotifier(this._initial);

  @override
  CompareState build() => _initial;
}

Widget _wrap(CompareState state) => ProviderScope(
  overrides: [
    compareNotifierProvider.overrideWith(() => _FakeCompareNotifier(state)),
  ],
  child: const MaterialApp(home: CompareScreen()),
);

void main() {
  testWidgets('renders without error', (tester) async {
    await tester.pumpWidget(_wrap(const CompareState()));
    expect(find.byType(CompareScreen), findsOneWidget);
  });

  testWidgets('shows loading indicator when isLoading is true', (tester) async {
    await tester.pumpWidget(_wrap(const CompareState(isLoading: true)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error text when state has error', (tester) async {
    await tester.pumpWidget(
      _wrap(const CompareState(error: 'Connection failed')),
    );
    expect(find.text('Connection failed'), findsOneWidget);
  });

  testWidgets('shows empty message when clusters is empty', (tester) async {
    await tester.pumpWidget(
      _wrap(const CompareState(clusters: [], isLoading: false)),
    );
    expect(find.text('No events to compare yet'), findsOneWidget);
  });

  testWidgets('shows category label when clusters is non-empty', (
    tester,
  ) async {
    final cluster = _infraCluster();
    await tester.pumpWidget(_wrap(CompareState(clusters: [cluster])));
    expect(find.textContaining('Infrastructure'), findsWidgets);
  });

  testWidgets('shows SUPPORTS badge for a supporting item', (tester) async {
    final cluster = _infraCluster();
    await tester.pumpWidget(_wrap(CompareState(clusters: [cluster])));
    expect(find.text('SUPPORTS'), findsWidgets);
  });

  testWidgets('shows CONTRADICTS badge for a contradicting item', (
    tester,
  ) async {
    final cluster = _mixedCluster();
    await tester.pumpWidget(_wrap(CompareState(clusters: [cluster])));
    expect(find.text('CONTRADICTS'), findsOneWidget);
  });
}

EventCluster _infraCluster() => EventCluster(
  id: 'infra_20260604',
  category: 'infra',
  date: DateTime(2026, 6, 4),
  items: [
    ClusterItem(
      id: '1',
      title: 'Power grid disrupted near Kharkiv',
      source: NewsSource.citizen,
      publishedAt: DateTime(2026, 6, 4, 9),
      eval: EvidenceEval.supports,
      confirmCount: 5,
      disputeCount: 1,
    ),
    ClusterItem(
      id: '2',
      title: 'Reuters: Substation attack confirmed',
      source: NewsSource.wire,
      publishedAt: DateTime(2026, 6, 4, 10),
      eval: EvidenceEval.supports,
      confirmCount: 0,
      disputeCount: 0,
    ),
  ],
);

EventCluster _mixedCluster() => EventCluster(
  id: 'combat_20260604',
  category: 'combat',
  date: DateTime(2026, 6, 4),
  items: [
    ClusterItem(
      id: '1',
      title: 'No military activity observed',
      source: NewsSource.citizen,
      publishedAt: DateTime(2026, 6, 4, 9),
      eval: EvidenceEval.contradicts,
      confirmCount: 1,
      disputeCount: 5,
    ),
    ClusterItem(
      id: '2',
      title: 'Shelling confirmed by multiple witnesses',
      source: NewsSource.citizen,
      publishedAt: DateTime(2026, 6, 4, 10),
      eval: EvidenceEval.supports,
      confirmCount: 6,
      disputeCount: 1,
    ),
  ],
);
