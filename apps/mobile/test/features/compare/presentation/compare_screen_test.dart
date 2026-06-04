import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/core/providers/vote_provider.dart';
import 'package:frontline/features/compare/domain/entities/event_cluster.dart';
import 'package:frontline/features/compare/presentation/providers/compare_provider.dart';
import 'package:frontline/features/compare/presentation/screens/compare_screen.dart';
import 'package:frontline/features/feed/data/datasources/vote_datasource.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeCompareNotifier extends CompareNotifier {
  final CompareState _initial;
  _FakeCompareNotifier(this._initial);

  @override
  CompareState build() => _initial;
}

class _FakeVoteDatasource implements VoteDatasource {
  final Map<String, String?> _votes;
  final List<({String reportId, String? type})> castCalls = [];

  _FakeVoteDatasource({Map<String, String?> votes = const {}}) : _votes = votes;

  @override
  Future<String?> getUserVote(String reportId) async => _votes[reportId];

  @override
  Future<void> castVote(String reportId, String? type) async {
    castCalls.add((reportId: reportId, type: type));
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

List<dynamic> _voteOverrides({
  Map<String, String?> userVotes = const {},
  Map<String, VoteCounts> liveCounts = const {},
}) {
  final ds = _FakeVoteDatasource(votes: userVotes);
  return [
    voteDatasourceProvider.overrideWithValue(ds),
    voteProvider.overrideWith((ref, id) async => userVotes[id]),
    voteCountsProvider.overrideWith(
      (ref, id) => Stream.value(liveCounts[id] ?? (confirm: 0, dispute: 0)),
    ),
  ];
}

Widget _wrap(
  CompareState state, {
  Map<String, String?> userVotes = const {},
  Map<String, VoteCounts> liveCounts = const {},
}) => ProviderScope(
  overrides: [
    compareNotifierProvider.overrideWith(() => _FakeCompareNotifier(state)),
    ..._voteOverrides(userVotes: userVotes, liveCounts: liveCounts),
  ],
  child: const MaterialApp(home: CompareScreen()),
);

Widget _wrapWithAnchor(
  CompareState state, {
  NewsItem? anchor,
  Map<String, String?> userVotes = const {},
  Map<String, VoteCounts> liveCounts = const {},
}) => ProviderScope(
  overrides: [
    compareNotifierProvider.overrideWith(() => _FakeCompareNotifier(state)),
    ..._voteOverrides(userVotes: userVotes, liveCounts: liveCounts),
  ],
  child: MaterialApp(home: CompareScreen(anchorItem: anchor ?? _citizenAnchor)),
);

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _citizenAnchor = NewsItem(
  id: 'a1',
  title: 'Strike near Kyiv',
  source: NewsSource.citizen,
  publishedAt: DateTime(2026, 6, 4, 9),
  category: 'combat',
  confirmCount: 2,
  disputeCount: 0,
);

final _wireAnchor = NewsItem(
  id: 'w1',
  title: 'Reuters: Explosion reported',
  source: NewsSource.wire,
  publishedAt: DateTime(2026, 6, 4, 10),
  category: 'combat',
  confirmCount: 0,
  disputeCount: 0,
);

EventCluster _infraCluster() => EventCluster(
  id: 'infra_20260604',
  category: 'infra',
  date: DateTime(2026, 6, 4),
  items: [
    ClusterItem(
      id: 'c1',
      title: 'Power grid disrupted near Kharkiv',
      source: NewsSource.citizen,
      publishedAt: DateTime(2026, 6, 4, 9),
      eval: EvidenceEval.supports,
      confirmCount: 5,
      disputeCount: 1,
    ),
    ClusterItem(
      id: 'c2',
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
      id: 'u1',
      title: 'Aid convoy status unclear',
      source: NewsSource.citizen,
      publishedAt: DateTime(2026, 6, 4, 8),
      eval: EvidenceEval.unverified,
      confirmCount: 0,
      disputeCount: 0,
    ),
    ClusterItem(
      id: 'u2',
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
      id: 'm1',
      title: 'No military activity observed',
      source: NewsSource.citizen,
      publishedAt: DateTime(2026, 6, 4, 9),
      eval: EvidenceEval.contradicts,
      confirmCount: 1,
      disputeCount: 5,
    ),
    ClusterItem(
      id: 'm2',
      title: 'Shelling confirmed by multiple witnesses',
      source: NewsSource.citizen,
      publishedAt: DateTime(2026, 6, 4, 10),
      eval: EvidenceEval.supports,
      confirmCount: 6,
      disputeCount: 1,
    ),
  ],
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Existing render/state tests ─────────────────────────────────────────────

  group('render and state', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_wrap(const CompareState()));
      expect(find.byType(CompareScreen), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading is true', (
      tester,
    ) async {
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
      await tester.pumpWidget(_wrap(CompareState(clusters: [_infraCluster()])));
      expect(find.textContaining('Infrastructure'), findsWidgets);
    });

    testWidgets('shows SUPPORTS badge for a supporting item', (tester) async {
      await tester.pumpWidget(_wrap(CompareState(clusters: [_infraCluster()])));
      expect(find.text('SUPPORTS'), findsWidgets);
    });

    testWidgets('shows CONTRADICTS badge for a contradicting item', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(CompareState(clusters: [_mixedCluster()])));
      expect(find.text('CONTRADICTS'), findsOneWidget);
    });

    testWidgets('shows UNVERIFIED badge for an unverified item', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CompareState(clusters: [_unverifiedCluster()])),
      );
      expect(find.text('UNVERIFIED'), findsWidgets);
    });
  });

  // ── Anchor (FeaturedItemCard) path ──────────────────────────────────────────

  group('anchor card', () {
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
  });

  // ── Vote buttons: citizen anchor ────────────────────────────────────────────

  group('FeaturedItemCard vote buttons — citizen anchor', () {
    testWidgets('shows confirm button (outline) when user has not voted', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapWithAnchor(const CompareState()));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows dispute button (outline) when user has not voted', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapWithAnchor(const CompareState()));
      await tester.pump();
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('shows filled confirm icon when user has voted confirm', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithAnchor(const CompareState(), userVotes: {'a1': 'confirm'}),
      );
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets('shows filled flag icon when user has voted dispute', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithAnchor(const CompareState(), userVotes: {'a1': 'dispute'}),
      );
      await tester.pump();
      expect(find.byIcon(Icons.flag), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
    });

    testWidgets('shows live confirm count from voteCountsProvider', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithAnchor(
          const CompareState(),
          // anchor has confirmCount: 2 initially; live stream says 7
          liveCounts: {'a1': (confirm: 7, dispute: 0)},
        ),
      );
      await tester.pump();
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('falls back to item count while voteCountsProvider loading', (
      tester,
    ) async {
      // Override with a stream that never emits (simulates loading)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            compareNotifierProvider.overrideWith(
              () => _FakeCompareNotifier(const CompareState()),
            ),
            voteDatasourceProvider.overrideWithValue(_FakeVoteDatasource()),
            voteProvider.overrideWith((ref, id) async => null),
            voteCountsProvider.overrideWith((ref, id) => const Stream.empty()),
          ],
          child: MaterialApp(home: CompareScreen(anchorItem: _citizenAnchor)),
        ),
      );
      await tester.pump();
      // Falls back to _citizenAnchor.confirmCount = 2
      expect(find.text('2'), findsOneWidget);
    });
  });

  // ── Vote buttons: wire anchor has none ──────────────────────────────────────

  group('FeaturedItemCard vote buttons — wire anchor', () {
    testWidgets('no confirm/dispute buttons for wire anchor', (tester) async {
      await tester.pumpWidget(
        _wrapWithAnchor(const CompareState(), anchor: _wireAnchor),
      );
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
      expect(find.byIcon(Icons.flag), findsNothing);
    });
  });

  // ── Vote buttons: timeline rows ─────────────────────────────────────────────

  group('_TimelineRow vote buttons', () {
    testWidgets('citizen cluster item shows confirm + dispute buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CompareState(clusters: [_infraCluster()]),
          liveCounts: {
            'c1': (confirm: 5, dispute: 1),
            'c2': (confirm: 0, dispute: 0),
          },
        ),
      );
      await tester.pump();
      // c1 is citizen — should have vote buttons
      expect(find.byIcon(Icons.check_circle_outline), findsWidgets);
      expect(find.byIcon(Icons.flag_outlined), findsWidgets);
    });

    testWidgets('wire cluster item has no vote buttons', (tester) async {
      // _infraCluster has c1 (citizen) + c2 (wire)
      // Only c1 should show vote buttons; wire c2 should not add any extras
      await tester.pumpWidget(
        _wrap(
          CompareState(clusters: [_infraCluster()]),
          liveCounts: {'c1': (confirm: 5, dispute: 1)},
        ),
      );
      await tester.pump();
      // There is exactly one citizen item (c1), so exactly one pair of buttons
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('shows live confirm count in timeline row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CompareState(clusters: [_infraCluster()]),
          liveCounts: {'c1': (confirm: 12, dispute: 3)},
        ),
      );
      await tester.pump();
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets(
      'active vote state highlighted in timeline row for voted item',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CompareState(clusters: [_infraCluster()]),
            userVotes: {'c1': 'confirm'},
            liveCounts: {'c1': (confirm: 6, dispute: 1)},
          ),
        );
        await tester.pump();
        // c1 voted confirm → filled icon
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      },
    );
  });

  // ── Vote button taps ────────────────────────────────────────────────────────

  group('vote casting', () {
    testWidgets('tapping confirm on anchor card calls castVote(confirm)', (
      tester,
    ) async {
      final ds = _FakeVoteDatasource();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            compareNotifierProvider.overrideWith(
              () => _FakeCompareNotifier(const CompareState()),
            ),
            voteDatasourceProvider.overrideWithValue(ds),
            voteProvider.overrideWith((ref, id) async => null),
            voteCountsProvider.overrideWith(
              (ref, id) => Stream.value((confirm: 2, dispute: 0)),
            ),
          ],
          child: MaterialApp(home: CompareScreen(anchorItem: _citizenAnchor)),
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pump();
      expect(ds.castCalls, hasLength(1));
      expect(ds.castCalls.first.reportId, 'a1');
      expect(ds.castCalls.first.type, 'confirm');
    });

    testWidgets('tapping dispute on anchor card calls castVote(dispute)', (
      tester,
    ) async {
      final ds = _FakeVoteDatasource();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            compareNotifierProvider.overrideWith(
              () => _FakeCompareNotifier(const CompareState()),
            ),
            voteDatasourceProvider.overrideWithValue(ds),
            voteProvider.overrideWith((ref, id) async => null),
            voteCountsProvider.overrideWith(
              (ref, id) => Stream.value((confirm: 2, dispute: 0)),
            ),
          ],
          child: MaterialApp(home: CompareScreen(anchorItem: _citizenAnchor)),
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pump();
      expect(ds.castCalls, hasLength(1));
      expect(ds.castCalls.first.reportId, 'a1');
      expect(ds.castCalls.first.type, 'dispute');
    });

    testWidgets('tapping confirm on a cluster timeline row calls castVote', (
      tester,
    ) async {
      final ds = _FakeVoteDatasource();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            compareNotifierProvider.overrideWith(
              () => _FakeCompareNotifier(
                CompareState(clusters: [_infraCluster()]),
              ),
            ),
            voteDatasourceProvider.overrideWithValue(ds),
            voteProvider.overrideWith((ref, id) async => null),
            voteCountsProvider.overrideWith(
              (ref, id) => Stream.value((confirm: 5, dispute: 1)),
            ),
          ],
          child: const MaterialApp(home: CompareScreen()),
        ),
      );
      await tester.pump();
      // _infraCluster has one citizen item (c1) → one confirm button
      await tester.tap(find.byIcon(Icons.check_circle_outline).first);
      await tester.pump();
      expect(ds.castCalls, hasLength(1));
      expect(ds.castCalls.first.type, 'confirm');
    });
  });
}
