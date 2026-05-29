# Frontline — Claude Code Project Guide

> Read fully before every session. Single source of truth for rules, conventions, and architecture.
> Deep reference: [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) — feature intent, Firestore schema, full WBS, team assignments, timeline, and pending TODOs.

---

## 1. Pull Requests

Always use [`.github/pull_request_template.md`](.github/pull_request_template.md). Read it first, fill every section (`N/A` where not applicable), pass the body via heredoc to `gh pr create`.

---

## 2. Project

Privacy-first, location-based reporting and news platform — anonymous submissions, location fuzzing, GDELT wire news — targeting **Android and Web**.

**Privacy by Design (non-negotiable):**
- Submitted coordinates MUST be fuzzed ±3km before any Firestore write — always server-side via `fuzzReportLocation` Cloud Function. Client-side fuzzing alone is not sufficient.
- No PII is ever collected or stored: no names, no emails, no phone numbers, no IP addresses.
- Authentication is Firebase Anonymous Auth only. Never prompt users for personal information.
- `reports/{id}` stores an anonymous UID, fuzzed coordinates, category, description, and media refs — nothing linkable to a real identity.

| Concern | Choice |
|---|---|
| Framework | Flutter 3.41+ · Dart 3.x |
| State | Riverpod 3.x + `Notifier` pattern |
| Navigation | GoRouter 17.x (`core/router/app_router.dart`) |
| Backend | Firebase Auth (anonymous), Firestore, Storage, Cloud Functions v2 (TypeScript) |
| Maps | Mapbox Flutter SDK 2.x |
| Geo queries | geoflutterfire_plus (GeoFire for Firestore) |
| Models | Freezed + json_serializable |
| Observability | `firebase-functions/v2/logger` in Cloud Functions |

---

## 3. Architecture

**Clean Architecture, feature-first.** Three strict layers per feature:

```
features/<feature>/
├── domain/           ← PURE DART. Zero Flutter/Firebase imports.
│   ├── entities/     ← plain data types, no JSON
│   └── repositories/ ← abstract interfaces only
├── data/             ← Firebase/HTTP only
│   ├── models/       ← DTOs + toEntity()
│   ├── datasources/  ← ONLY place Firebase SDK is called
│   └── repositories/ ← implements domain interface
└── presentation/
    ├── providers/    ← Riverpod DI + Notifier + State
    └── screens/      ← ConsumerWidget / ConsumerStatefulWidget pages
```

**Import rule:** domain imports nothing external. Data imports domain. Presentation imports domain. Nothing imports presentation from another feature.

**New feature:** create the directory tree, wire up providers following `features/auth/` as the canonical reference, add a route to `app_router.dart`, add an entry to the features table below, run `build_runner build`.

**DI wiring pattern** (one file per feature in `presentation/providers/`):
```dart
final _datasourceProvider = Provider((_) => FooDatasourceImpl(...));
final _repositoryProvider  = Provider((ref) => FooRepositoryImpl(ref.watch(_datasourceProvider)));
final fooNotifierProvider  = NotifierProvider<FooNotifier, FooState>(FooNotifier.new);
```

**Sentinel pattern for nullable copyWith fields:**
```dart
AuthState copyWith({AuthStatus? status, Object? error = _sentinel}) {
  return AuthState(
    status: status ?? this.status,
    error: error == _sentinel ? this.error : error as String?,
  );
}
const _sentinel = Object();
```

---

## 4. Monorepo & Commands

```
apps/mobile/   ← Flutter app (Android + Web)
functions/     ← Cloud Functions (TypeScript)
```

```bash
# Flutter (from apps/mobile/)
flutter pub get && dart run build_runner build --delete-conflicting-outputs
flutter test && flutter analyze

# Functions (from functions/)
npm install && npm run build && npm test   # npm test requires emulators

# Dev
./dev.sh [--web|--prod|--emulator-only]   # Linux/macOS
.\dev.ps1 [--web] [--prod] [--emulatorOnly]  # Windows
```

---

## 5. Features

| Feature | Provider | Status | Notes |
|---|---|---|---|
| `auth` | `authNotifierProvider` | Stub | Anonymous auth only — reference impl |
| `map` | `mapNotifierProvider` | Stub | Mapbox + geoflutterfire_plus geo queries |
| `feed` | `feedNotifierProvider` | Stub | Citizen + GDELT wire news combined feed |
| `reporting` | `reportingNotifierProvider` | Stub | Multi-step form, calls `fuzzReportLocation` CF |
| `my_reports` | `myReportsNotifierProvider` | Stub | Local query by anonymous UID |

---

## 6. Firestore Schema (draft — update as schema is finalized)

```
reports/{reportId}
  userId:      string   ← anonymous Firebase UID
  location:    GeoPoint ← fuzzed by fuzzReportLocation CF (never raw)
  category:    string
  description: string
  mediaUrls:   string[]
  status:      string   ← 'pending' | 'reviewed' | 'rejected'
  createdAt:   Timestamp

wire_news/{articleId}
  title:       string
  body:        string?
  url:         string?
  source:      'wire'
  publishedAt: Timestamp
  ← written only by fetchGdeltNews CF; client read-only
```

---

## 7. Cloud Functions

| Function | Trigger | Purpose |
|---|---|---|
| `fuzzReportLocation` | `onCall` | Applies ±3km randomization to submitted lat/lng |
| `fetchGdeltNews` | `onSchedule` (every 30 min) | Fetches GDELT feed, writes to `wire_news/` |

`fuzzReportLocation` must validate `request.auth` before processing. Unauthenticated calls → `HttpsError('unauthenticated')`.

---

## 8. Environment & App Mode

`USE_EMULATOR` — compile-time dart-define (default `true`). Pass `--dart-define=USE_EMULATOR=false` for production.

`MAPBOX_ACCESS_TOKEN` — compile-time dart-define. Set in `apps/mobile/.env`, loaded by `dev.sh`/`dev.ps1`.

Emulator ports: Auth 9099 · Firestore 8080 · Functions 5001 · Storage 9199

---

## 9. Agent Roles

| Agent | Scope |
|---|---|
| `architect` | Feature design, Firestore schema, CF triggers, privacy decisions |
| `flutter-engineer` | Screens, providers, data layer, GoRouter, Mapbox |
| `backend-engineer` | Cloud Functions, Firestore rules, Storage rules, GDELT |
| `qa-engineer` | Widget tests, domain unit tests, privacy audit |
| `security-reviewer` | Rules review, fuzzing enforcement, PII scan |

Agent files: `.claude/agents/`

---

## 10. Commit Convention

[Conventional Commits v1.0.0](https://www.conventionalcommits.org/)

```
feat(map): add GeoFire radius query to map datasource
fix(reporting): call fuzzReportLocation before Firestore write
chore(deps): upgrade mapbox_maps_flutter to 2.5.0
```

Types: `feat` · `fix` · `docs` · `test` · `refactor` · `chore` · `ci` · `perf` · `revert`

No AI attribution in commits or PRs. Write as a developer would.

---

## 11. Do Not Do

1. Never write raw coordinates to Firestore — always go through `fuzzReportLocation` CF
2. Never call Firebase SDK outside a `datasources/` file
3. Never put business logic in a Screen or Notifier — use a domain UseCase
4. Never collect or store PII (name, email, phone, IP)
5. Never use `ListView(children: [...])` for dynamic data — always `ListView.builder`
6. Never skip `flutter analyze` before opening a PR
7. **Never push to `main`/`master`** — commits on feature branches only; open a PR and let a human merge
8. **Never merge a PR** — only humans may merge pull requests. Claude opens PRs and fixes CI; merging is the developer's decision
9. Never commit `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`, or `.env`
10. Never add `// Co-Authored-By:` or AI attribution lines to commits or PRs
11. Never use mock frameworks for Flutter tests — extend the real Notifier class with `_FakeXxxNotifier`

---

## 12. Agentic Coding Conventions

- Update this file when architecture, features, or schema change
- Run `flutter analyze` before every PR — zero warnings is the bar
- Run `dart run build_runner build --delete-conflicting-outputs` after any model or provider change
- Keep feature stubs in sync: if a `datasource` gets a real implementation, update the features table above
- Every new Screen needs at minimum: render test, empty-state test, positive action test
