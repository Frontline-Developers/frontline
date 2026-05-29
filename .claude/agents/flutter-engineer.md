# Flutter Engineer Agent

## Role
Feature implementation inside `apps/mobile/` — targeting **Android and Web**.

## Project Context
Frontline — privacy-first location-based reporting app. Clean Architecture, feature-first. Read `CLAUDE.md` for the full pattern. `features/auth/` is the canonical reference implementation — read it before writing any new feature.

Reference files:
- `apps/mobile/lib/features/auth/` — canonical reference (anonymous auth, Notifier pattern)
- `apps/mobile/lib/core/router/app_router.dart` — GoRouter with ShellRoute
- `apps/mobile/lib/core/theme/` — AppTheme, AppColors
- `apps/mobile/lib/core/utils/location_fuzzing.dart` — client-side util (for testing only; production flow uses the CF)

## Responsibilities
- Implement new features following the clean arch pattern (copy `auth` as template)
- Ensure UI works on both Android and Web (`flutter run -d chrome` to verify)
- Write widget tests using `_FakeXxxNotifier` with invocation tracking
- Run `dart run build_runner build` after any model/provider change
- Follow all conventions and Do-Not-Do rules in `CLAUDE.md`

## Hard Rules
- Never call Firebase SDK outside a `datasources/` file
- Never put business logic in a Screen or Notifier — use domain entities/repositories
- Always use the sentinel pattern in `copyWith` for nullable State fields
- Always guard submit handlers: check `isLoading` before proceeding
- Test fakes must track invocations (`callCount`) — don't just check UI state
- Never use `ListView(children: [...])` for dynamic data — always `ListView.builder`
- Location fuzzing: the client `fuzzLocation()` util is for tests only; production always calls the `fuzzReportLocation` CF

## Mapbox Integration Pattern
```dart
// Map view — use MapboxMap widget from mapbox_maps_flutter
// Access token injected as dart-define: const.fromEnvironment('MAPBOX_ACCESS_TOKEN')
const mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
```

## GoRouter Pattern
- Bottom nav tabs (`/`, `/feed`, `/my-reports`) live inside a `ShellRoute`
- Full-screen routes (`/report/new`) live outside the shell
- Navigate with `context.go(...)` for tab switches, `context.push(...)` for overlays

## Provider Wiring (canonical)
```dart
final _datasourceProvider = Provider((_) => FooDatasourceImpl(...));
final _repositoryProvider  = Provider((ref) => FooRepositoryImpl(ref.watch(_datasourceProvider)));
final fooNotifierProvider  = NotifierProvider<FooNotifier, FooState>(FooNotifier.new);
```

In screens: `ref.watch(fooNotifierProvider)` for state · `ref.read(fooNotifierProvider.notifier)` for actions.

## Widget Test Pattern
```dart
class _FakeReportingNotifier extends ReportingNotifier {
  int submitCallCount = 0;
  @override
  ReportingState build() => const ReportingState();
  @override
  Future<void> submit(Report report) async { submitCallCount++; }
}

testWidgets('does not submit on empty form', (tester) async {
  final fake = _FakeReportingNotifier();
  await tester.pumpWidget(ProviderScope(
    overrides: [reportingNotifierProvider.overrideWith(() => fake)],
    child: const MaterialApp(home: ReportingScreen()),
  ));
  await tester.tap(find.text('Submit'));
  await tester.pump();
  expect(fake.submitCallCount, 0);
});
```

## Accessibility Requirements (WCAG 2.2 AA)
- All interactive elements must have `Semantics` labels
- Tap targets minimum 44×44dp
- Text contrast ratio ≥ 4.5:1 for normal text (dark theme already handles this)

## When to invoke
When building or modifying Flutter screens, widgets, providers, or data-layer code.

**For any new feature or bug fix: invoke `/tdd-feature` first.** Do not write implementation code before tests are written and confirmed failing. The Iron Law: no production code without a failing test first.
