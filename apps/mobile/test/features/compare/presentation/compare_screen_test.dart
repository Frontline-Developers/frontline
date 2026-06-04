import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/compare/domain/entities/event_cluster.dart';
import 'package:frontline/features/compare/presentation/providers/compare_provider.dart'
    show
        CompareNotifier,
        CompareState,
        compareNotifierProvider,
        wireNewsForItemProvider;
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

final _anchor = NewsItem(
  id: 'a1',
  title: 'Strike near Kyiv',
  source: NewsSource.citizen,
  publishedAt: DateTime(2026, 6, 4, 9),
  category: 'combat',
  status: ItemStatus.pending,
);

Widget _wrapWithAnchor(CompareState state, {NewsItem? anchor}) => ProviderScope(
  overrides: [
    compareNotifierProvider.overrideWith(() => _FakeCompareNotifier(state)),
    wireNewsForItemProvider.overrideWith((ref, arg) async => []),
  ],
  child: MaterialApp(home: CompareScreen(anchorItem: anchor ?? _anchor)),
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

  testWidgets('shows UNVERIFIED badge for an unverified item', (tester) async {
    await tester.pumpWidget(
      _wrap(CompareState(clusters: [_unverifiedCluster()])),
    );
    expect(find.text('UNVERIFIED'), findsWidgets);
  });

  // ── Anchor (FeaturedItemCard) path ────────────────────────────────────────

  testWidgets('shows anchor title in FeaturedItemCard when anchorItem set', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapWithAnchor(const CompareState()));
    expect(find.text('Strike near Kyiv'), findsOneWidget);
  });

  testWidgets('shows COMPARING label when anchorItem set', (tester) async {
    await tester.pumpWidget(_wrapWithAnchor(const CompareState()));
    expect(find.text('COMPARING'), findsOneWidget);
  });

  testWidgets('shows back arrow icon when anchorItem set', (tester) async {
    await tester.pumpWidget(_wrapWithAnchor(const CompareState()));
    expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
  });

  testWidgets(
    'shows no-related-reports empty state when anchor has no matching clusters',
    (tester) async {
      await tester.pumpWidget(_wrapWithAnchor(const CompareState()));
      expect(find.text('No related reports yet'), findsOneWidget);
    },
  );

  testWidgets('shows Related reports header when anchorItem set', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapWithAnchor(const CompareState()));
    expect(find.text('Related reports'), findsOneWidget);
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

EventCluster _unverifiedCluster() => EventCluster(
  id: 'aid_20260604',
  category: 'aid',
  date: DateTime(2026, 6, 4),
  items: [
    ClusterItem(
      id: '1',
      title: 'Aid convoy status unclear',
      source: NewsSource.citizen,
      publishedAt: DateTime(2026, 6, 4, 8),
      eval: EvidenceEval.unverified,
      confirmCount: 0,
      disputeCount: 0,
    ),
    ClusterItem(
      id: '2',
      title: 'Convoy reported delayed',
      source: NewsSource.citizen,
      publishedAt: DateTime(2026, 6, 4, 9),
      eval: EvidenceEval.unverified,
      confirmCount: 1,
      disputeCount: 1,
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
