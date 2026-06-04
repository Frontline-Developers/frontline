import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/map/presentation/providers/map_provider.dart';
import 'package:frontline/features/map/presentation/screens/map_screen.dart';

class _FakeMapNotifier extends MapNotifier {
  final MapState _initial;
  _FakeMapNotifier(this._initial);

  @override
  MapState build() => _initial;
}

Widget _wrap(MapState state) => ProviderScope(
  overrides: [mapNotifierProvider.overrideWith(() => _FakeMapNotifier(state))],
  child: const MaterialApp(home: MapScreen()),
);

void main() {
  testWidgets('renders without error', (tester) async {
    await tester.pumpWidget(_wrap(const MapState()));
    expect(find.byType(MapScreen), findsOneWidget);
  });

  testWidgets('shows map placeholder text', (tester) async {
    await tester.pumpWidget(_wrap(const MapState()));
    expect(find.textContaining('Map view'), findsOneWidget);
  });

  testWidgets('shows app bar title', (tester) async {
    await tester.pumpWidget(_wrap(const MapState()));
    expect(find.text('Frontline'), findsOneWidget);
  });

  group('MapState', () {
    test('default state has empty reports', () {
      const state = MapState();
      expect(state.reports, isEmpty);
    });

    test('default isLoading is false', () {
      const state = MapState();
      expect(state.isLoading, isFalse);
    });

    test('copyWith updates isLoading', () {
      const state = MapState();
      expect(state.copyWith(isLoading: true).isLoading, isTrue);
    });

    test('copyWith preserves error through sentinel', () {
      const state = MapState(error: 'fail');
      expect(state.copyWith(isLoading: false).error, 'fail');
    });

    test('copyWith clears error with explicit null', () {
      const state = MapState(error: 'fail');
      expect(state.copyWith(error: null).error, isNull);
    });
  });
}
