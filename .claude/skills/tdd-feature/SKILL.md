---
name: tdd-feature
description: Use when implementing any feature or bugfix — write the test first, watch it fail, write minimal code to pass. Ensures tests actually verify behavior by requiring failure first. ALWAYS invoke this before writing implementation code.
allowed-tools: AskUserQuestion, Write, Read, Bash
---

# Test-Driven Development

## Core Principle

Write the test first. Watch it fail. Write minimal code to pass.

**If you didn't watch the test fail, you don't know if it tests the right thing.**

Violating the letter of the rules is violating the spirit of the rules.

---

## The Iron Law

**NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST**

Write code before the test? Delete it. Start over.

No exceptions:
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- **Delete means delete**

Implement fresh from tests. Period.

---

## When to Use

**Always:**
- New features
- Bug fixes
- Refactoring
- Behaviour changes

**Exceptions (ask your human partner):**
- Throwaway prototypes
- Generated code (Freezed, Riverpod codegen)
- Configuration files

Thinking "skip TDD just this once"? Stop. That's rationalization.

---

## Red-Green-Refactor Cycle

### RED — Write failing test

Write one minimal test that describes what should happen.

```dart
test('returns reports ordered by createdAt descending', () async {
  final repo = FakeReportingRepository();
  repo.stubbedReports = [reportOld, reportNew];
  final usecase = GetMyReports(repo);

  final result = await usecase(userId: 'uid-123');

  expect(result, [reportNew, reportOld]);
});
```

Requirements:
- One behaviour per test
- Clear name describing behaviour (not `test('works')`)
- Tests real code — not mock return values
- Must fail because feature doesn't exist yet

Run:
```bash
cd apps/mobile && flutter test test/features/<name>/ --no-pub
```

Confirm:
- Test **FAILS** (not compile errors)
- Failure message is expected — "method not found", "null returned", etc.
- Fails because feature is missing, not because of typos

Test passes immediately? You're testing existing behaviour. Fix the test.
Test errors on compile? Fix import/syntax errors, re-run until it **fails** correctly.

### GREEN — Minimal implementation

Write the simplest code that makes the failing test pass.

- Don't add features the test doesn't require
- Don't refactor other code
- Don't "improve" beyond what the test needs
- Run `flutter test` after each small step

### REFACTOR — Clean up

After green only:
- Remove duplication
- Improve names
- Extract helpers
- Keep tests green throughout
- Don't add new behaviour

**Repeat** for each behaviour.

---

## Workflow

### Step 1 — Plan and gather context

- Read `CLAUDE.md` and `PROJECT_CONTEXT.md`
- Read the existing feature folder if it exists
- If acceptance criteria are unclear, **ask the human partner before writing any tests**
- Write a short Feature Definition:
  - What the feature does
  - States it can be in (idle, loading, success, empty, error)
  - User actions it supports
  - Known edge cases

### Step 2 — Write ALL tests first (RED)

Write every test for the feature **before any implementation code**.

Files go in `apps/mobile/test/features/<name>/`:
```
test/features/<name>/
├── domain/
│   └── <usecase>_test.dart
└── presentation/
    └── <name>_screen_test.dart
```

Run and confirm **every test fails**:
```bash
cd apps/mobile && flutter test test/features/<name>/ --no-pub
```

Show failure output. If any test passes, investigate before continuing.

### Step 3 — Confirm RED

Every test must fail. If any pass, you may be testing existing behaviour — fix the test.

### Step 4 — Implement (GREEN)

Implement in this order:
1. Domain layer (entities → repositories → usecases)
2. Data layer (models → datasources → repository impl)
3. Presentation layer (providers → screens)

Run tests after each layer. **Never modify a test to make it pass — only modify implementation code.**

**Allowed exceptions for modifying a test:**
- Syntax error caused by a renamed entity field (update import/field name only)
- Test was genuinely testing the wrong thing — justify out loud before editing
- Import path changed by a structural refactor

### Step 5 — All green + verify

```bash
cd apps/mobile && flutter test test/features/<name>/ --no-pub
flutter analyze
flutter test --no-pub   # full suite — confirm no regressions
```

Zero failures + zero analyze issues = feature complete.

---

## Flutter/Dart Test Patterns

### Domain unit tests

```dart
// test/features/reporting/domain/submit_report_test.dart

void main() {
  late FakeReportingRepository repo;

  setUp(() => repo = FakeReportingRepository());

  group('SubmitReport', () {
    test('returns report id on success', () async {
      repo.stubbedId = 'report-123';
      final result = await SubmitReport(repo)(report: validReport);
      expect(result, 'report-123');
    });

    test('throws when description is empty', () async {
      final emptyReport = validReport.copyWith(description: '');
      expect(
        () => SubmitReport(repo)(report: emptyReport),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('calls fuzz before writing', () async {
      await SubmitReport(repo)(report: validReport);
      expect(repo.fuzzWasCalled, isTrue);
    });
  });
}

class FakeReportingRepository implements ReportingRepository {
  String stubbedId = 'fake-id';
  bool fuzzWasCalled = false;

  @override
  Future<String> submitReport(Report report) async {
    fuzzWasCalled = true;
    return stubbedId;
  }
}
```

### Widget tests

```dart
// test/features/reporting/presentation/reporting_screen_test.dart

class _FakeReportingNotifier extends ReportingNotifier {
  int submitCallCount = 0;
  ReportingState initialState;

  _FakeReportingNotifier({this.initialState = const ReportingState()});

  @override
  ReportingState build() => initialState;

  @override
  Future<void> submit(Report report) async {
    submitCallCount++;
  }
}

void main() {
  testWidgets('shows form in idle state', (tester) async {
    await tester.pumpWidget(_wrap(const ReportingState()));
    expect(find.byType(TextField), findsWidgets);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('submit button disabled while loading', (tester) async {
    await tester.pumpWidget(
      _wrap(const ReportingState(status: ReportingStatus.loading)),
    );
    final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('does not submit on empty form', (tester) async {
    final fake = _FakeReportingNotifier();
    await tester.pumpWidget(_wrapWith(fake));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(fake.submitCallCount, 0);
  });

  testWidgets('shows error message on error state', (tester) async {
    await tester.pumpWidget(
      _wrap(const ReportingState(
        status: ReportingStatus.error,
        error: 'Submission failed',
      )),
    );
    expect(find.text('Submission failed'), findsOneWidget);
  });
}

Widget _wrap(ReportingState state) => _wrapWith(_FakeReportingNotifier(initialState: state));

Widget _wrapWith(_FakeReportingNotifier fake) => ProviderScope(
  overrides: [reportingNotifierProvider.overrideWith(() => fake)],
  child: const MaterialApp(home: ReportingScreen()),
);
```

### Minimum tests per feature

| Layer | Required tests |
|---|---|
| Domain UseCase | happy path, empty/null result, error/exception, ≥1 edge case |
| Screen | render in each State variant, user action, loading guard, error display |

Never skip edge cases to "save time" — edge cases are the point of TDD.

---

## Test Quality Rules

| Quality | Good | Bad |
|---|---|---|
| Minimal | Tests one thing. "and" in name? Split it. | `test('validates email and password')` |
| Clear | Name describes behaviour | `test('test1')`, `test('works')` |
| Real | Tests actual code paths | Asserts on fake/mock types |
| Failing | Fails before implementation | Passes immediately |

---

## Anti-Patterns

### 1. Testing mock/fake behaviour

```dart
// ❌ BAD — testing that the fake type is rendered
expect(find.byType(FakeMapDatasource), findsOneWidget);

// ✅ GOOD — test what the user sees
expect(find.text('Map loading...'), findsOneWidget);
```

### 2. Test-only methods in production classes

```dart
// ❌ BAD
class ReportingNotifier extends Notifier<ReportingState> {
  void resetForTesting() => state = const ReportingState();
}

// ✅ GOOD — the fake handles its own state
class _FakeReportingNotifier extends ReportingNotifier {
  @override
  ReportingState build() => const ReportingState();
}
```

### 3. Mocking without understanding

Don't mock a method that has a side effect your test depends on. Run with the real implementation first, observe what the test needs, then mock only the slow or external parts (Firebase, HTTP).

### 4. Incomplete fakes

Mirror the full entity/state structure. Missing fields in a fake cause silent failures when downstream code accesses them.

---

## Red Flags — Stop and Start Over

These all mean: **delete the implementation code, start over.**

- Code written before test
- Test passes immediately without implementation
- Can't explain why the test failed
- "Tests added later"
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "Just this once"
- "Keep as reference"
- "TDD is too slow for this"

---

## Verification Checklist

Before marking any feature complete:

- [ ] Every new UseCase / method has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for the expected reason (feature missing — not typos)
- [ ] Wrote minimal code to pass each test
- [ ] All feature tests pass
- [ ] `flutter analyze` — zero issues
- [ ] Full `flutter test` suite — zero regressions
- [ ] No test-only methods in production code
- [ ] No tests that assert on mock/fake types
- [ ] All edge cases and error paths covered

Can't check all boxes? You skipped TDD. **Start over.**
