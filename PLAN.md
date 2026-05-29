# Plan: Initialize Frontline Flutter Project

## Context

The `frontline` repo currently contains only a LICENSE file. It needs a full Flutter project scaffolded to match CozyTalk's patterns — same tech stack, same Clean Architecture, same agentic-dev conventions — but adapted for a privacy-first, location-based news/reporting app (Mapbox, anonymous auth, location fuzzing, GDELT). Five developers will work on this concurrently using Claude Code, so the `.claude/` setup, `CLAUDE.md`, scripts, and skills are as important as the source code.

**Platforms:** Android + Web  
**CozyTalk source of truth:** `~/Projects/CozyTalk/apps/mobile/` and `~/Projects/CozyTalk/.claude/`

---

## Final Repo Structure

```
frontline/
├── apps/mobile/                  ← Flutter app (android + web)
│   ├── lib/
│   ├── android/
│   ├── web/
│   ├── test/
│   ├── assets/images/ assets/icons/
│   ├── pubspec.yaml
│   ├── analysis_options.yaml
│   └── .env + .env.example
├── functions/                    ← Cloud Functions (TypeScript)
│   ├── src/index.ts, gdelt.ts, locationFuzzing.ts
│   ├── package.json
│   └── tsconfig.json
├── .github/pull_request_template.md
├── .claude/
│   ├── settings.json
│   ├── agents/architect.md, flutter-engineer.md, backend-engineer.md, qa-engineer.md, security-reviewer.md
│   ├── hooks/enforce-pr-template.sh, enforce-authorship.sh
│   └── skills/github-pr-review/SKILL.md, firebase-deploy/SKILL.md, privacy-audit/SKILL.md, feature-scaffold/SKILL.md
├── CLAUDE.md
├── firebase.json
├── firestore.rules
├── firestore.indexes.json
├── storage.rules
├── .firebaserc
├── .gitignore
├── setup.sh                      ← first-time setup (Linux/macOS)
├── setup.ps1                     ← first-time setup (Windows)
├── dev.sh                        ← dev runner (Linux/macOS)
└── dev.ps1                       ← dev runner (Windows)
```

---

## Step-by-Step Implementation

### 1. Scaffold Flutter App

```bash
cd ~/Projects/frontline
flutter create apps/mobile --org com.frontlineapp --project-name frontline --platforms android,web
```

Delete default boilerplate:
- Wipe `apps/mobile/lib/main.dart` (replace with clean version)
- Delete `apps/mobile/test/widget_test.dart`
- Create `apps/mobile/assets/images/.gitkeep` and `apps/mobile/assets/icons/.gitkeep`

---

### 2. `apps/mobile/pubspec.yaml`

```yaml
name: frontline
description: "Frontline - Privacy-focused location-based reporting & news"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.9.0

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.9
  shared_preferences: ^2.2.2

  # Firebase
  firebase_core: ^4.7.0
  firebase_auth: ^6.4.0
  cloud_firestore: ^6.4.0
  firebase_storage: ^13.4.0
  cloud_functions: ^6.2.0
  firebase_app_check: ^0.3.2+5

  # State management
  flutter_riverpod: ^3.3.1
  riverpod_annotation: ^4.0.2

  # Navigation
  go_router: ^17.2.3

  # Models
  freezed_annotation: ^3.1.0
  json_annotation: ^4.11.0

  # Maps
  mapbox_maps_flutter: ^2.4.0

  # Media
  image_picker: ^1.1.2

  # Geo queries (GeoFire for Firestore)
  geoflutterfire_plus: ^0.0.31

  # Utilities
  flutter_secure_storage: ^10.3.0
  flutter_svg: ^2.0.17
  google_fonts: ^8.1.0
  http: ^1.6.0
  connectivity_plus: ^7.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  riverpod_generator: ^4.0.3
  build_runner: ^2.15.0
  freezed: ^3.2.5
  json_serializable: ^6.13.0
  integration_test:
    sdk: flutter

dependency_overrides:
  test_api: 0.7.10
  path_provider_foundation: 2.4.4

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
```

---

### 3. `apps/mobile/analysis_options.yaml`

Copy exactly from CozyTalk:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    use_null_aware_elements: false

analyzer:
  exclude:
    - build/**
```

---

### 4. `apps/mobile/.env.example`

```
# true → local emulators (use this for local dev)
# false → production Firebase
USE_EMULATOR=true

# Mapbox public access token — required for map rendering
# Get a token at https://account.mapbox.com/access-tokens/
MAPBOX_ACCESS_TOKEN=
```

---

### 5. `lib/` Feature-First Structure

Create directories and stub files:

```
apps/mobile/lib/
├── main.dart
├── firebase_options.dart           # TODO placeholder — run flutterfire configure
├── core/
│   ├── router/
│   │   └── app_router.dart        # GoRouter (5 routes + bottom nav shell)
│   ├── theme/
│   │   ├── app_colors.dart        # Dark journalism palette
│   │   └── app_theme.dart         # ThemeData (Material3, dark)
│   └── utils/
│       └── location_fuzzing.dart  # ±3km randomization
├── features/
│   ├── auth/                      # Anonymous Firebase Auth
│   │   ├── domain/
│   │   │   ├── entities/user_identity.dart
│   │   │   └── repositories/auth_repository.dart
│   │   ├── data/
│   │   │   ├── datasources/auth_datasource.dart
│   │   │   └── repositories/auth_repository_impl.dart
│   │   └── presentation/
│   │       └── providers/auth_provider.dart
│   ├── map/                       # Mapbox interactive feed
│   │   ├── domain/
│   │   │   ├── entities/map_report.dart
│   │   │   └── repositories/map_repository.dart
│   │   ├── data/
│   │   │   ├── models/map_report_model.dart
│   │   │   ├── datasources/map_datasource.dart
│   │   │   └── repositories/map_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/map_provider.dart
│   │       └── screens/map_screen.dart
│   ├── feed/                      # Citizen + Wire news feed
│   │   ├── domain/
│   │   │   ├── entities/news_item.dart
│   │   │   └── repositories/feed_repository.dart
│   │   ├── data/
│   │   │   ├── models/news_item_model.dart
│   │   │   ├── datasources/feed_datasource.dart
│   │   │   └── repositories/feed_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/feed_provider.dart
│   │       └── screens/feed_screen.dart
│   ├── reporting/                 # Multi-step anonymous form + media
│   │   ├── domain/
│   │   │   ├── entities/report.dart
│   │   │   └── repositories/reporting_repository.dart
│   │   ├── data/
│   │   │   ├── models/report_model.dart
│   │   │   ├── datasources/reporting_datasource.dart
│   │   │   └── repositories/reporting_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/reporting_provider.dart
│   │       └── screens/reporting_screen.dart
│   └── my_reports/               # Local user submission history
│       ├── domain/
│       │   ├── entities/my_report.dart
│       │   └── repositories/my_reports_repository.dart
│       ├── data/
│       │   ├── models/my_report_model.dart
│       │   ├── datasources/my_reports_datasource.dart
│       │   └── repositories/my_reports_repository_impl.dart
│       └── presentation/
│           ├── providers/my_reports_provider.dart
│           └── screens/my_reports_screen.dart
└── shared/
    └── widgets/
        └── loading_indicator.dart
```

---

### 6. Core File Contents

**`main.dart`** — mirrors CozyTalk pattern:
- `Firebase.initializeApp()` with `USE_EMULATOR` dart-define (default `true`)
- Emulator setup if `USE_EMULATOR == 'true'`: Auth :9099, Firestore :8080, Functions :5001, Storage :9199
- `ProviderScope` wrapping `MaterialApp.router`
- GoRouter from `core/router/app_router.dart`
- `AppTheme.darkTheme`

**`core/router/app_router.dart`** — GoRouter with ShellRoute (bottom nav) + 5 routes:
- `/` → MapScreen (home)
- `/feed` → FeedScreen
- `/report/new` → ReportingScreen (full-screen, outside shell)
- `/report/:id` → ReportDetailScreen (stub)
- `/my-reports` → MyReportsScreen

**`core/theme/app_colors.dart`** — Dark journalism palette:
```dart
scaffoldBg:   Color(0xFF0D0D0D)  // near-black
cardBg:       Color(0xFF1A1A1A)
surfaceAlt:   Color(0xFF222222)
accent:       Color(0xFFE63946)  // red — urgency/breaking
accentWire:   Color(0xFF457B9D) // blue — wire news
accentCitizen:Color(0xFF2A9D8F) // teal — citizen reports
textPrimary:  Color(0xFFEAEAEA)
textMuted:    Color(0xFF888888)
divider:      Color(0xFF333333)
```

**`core/utils/location_fuzzing.dart`**:
```dart
import 'dart:math';

// Randomize lat/lng within ±3km radius.
// 1° lat ≈ 111km | 1° lng ≈ 111km * cos(lat_rad)
(double lat, double lng) fuzzLocation(double lat, double lng) {
  final rng = Random.secure();
  const radiusKm = 3.0;
  final u = rng.nextDouble();
  final v = rng.nextDouble();
  final w = radiusKm / 111.0 * sqrt(u);
  final t = 2 * pi * v;
  return (
    lat + w * cos(t),
    lng + w * sin(t) / cos(lat * pi / 180),
  );
}
```

**`firebase_options.dart`** — stub:
```dart
// TODO: Run `flutterfire configure --project=<your-project-id>` to generate this file.
// See setup.sh for instructions.
import 'package:firebase_core/firebase_core.dart';
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnimplementedError('Run flutterfire configure first.');
}
```

---

### 7. `functions/` — Cloud Functions skeleton

**`functions/package.json`** — copy CozyTalk's pattern:
- TypeScript, firebase-functions v4, firebase-admin v12
- Scripts: `build`, `build:watch`, `lint`, `test`
- engines: `{ "node": "24" }`

**`functions/tsconfig.json`** — copy CozyTalk's tsconfig

**`functions/src/index.ts`** — typed stubs:
```typescript
export { fetchGdeltNews } from './gdelt';
export { fuzzReportLocation } from './locationFuzzing';
```

**`functions/src/gdelt.ts`** — scheduled CF stub (runs every 30 min, fetches GDELT JSON feed, writes to Firestore `wire_news/`):
```typescript
import { onSchedule } from 'firebase-functions/v2/scheduler';
// TODO: implement GDELT fetch
export const fetchGdeltNews = onSchedule('every 30 minutes', async () => {});
```

**`functions/src/locationFuzzing.ts`** — callable CF stub (accepts `{lat, lng}`, applies ±3km fuzz, returns fuzzed coords):
```typescript
import { onCall } from 'firebase-functions/v2/https';
// TODO: implement ±3km fuzz server-side
export const fuzzReportLocation = onCall(async (request) => {
  return { lat: request.data.lat, lng: request.data.lng };
});
```

---

### 8. Firebase Config Files

**`firebase.json`**:
```json
{
  "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" },
  "functions": [{ "source": "functions", "codebase": "default" }],
  "storage": { "rules": "storage.rules" },
  "emulators": {
    "auth":      { "port": 9099 },
    "functions": { "port": 5001 },
    "firestore": { "port": 8080 },
    "storage":   { "port": 9199 },
    "ui":        { "enabled": true, "port": 4000 }
  }
}
```

**`firestore.rules`** — stub with deny-all default + placeholder for report rules  
**`firestore.indexes.json`** — `{ "indexes": [], "fieldOverrides": [] }`  
**`storage.rules`** — stub deny-all  
**`.firebaserc`** — `{ "projects": { "default": "TODO-your-project-id" } }`

---

### 9. `.gitignore`

Standard Flutter `.gitignore` plus:
```
# Firebase — generated per-dev, not committed
google-services.json
GoogleService-Info.plist
apps/mobile/lib/firebase_options.dart

# Secrets
apps/mobile/.env
*.env
.env.*

# Builds
apps/mobile/build/
functions/lib/
functions/node_modules/
```

---

### 10. `setup.sh`

Mirrors CozyTalk's `setup.sh` exactly in style and structure, adapted for frontline:

**Flow:**
1. Header: `Frontline · project setup`
2. **Prerequisites check:** flutter (≥ Dart 3.9), node (≥ 24), npm, java (≥ 21), firebase-tools, flutterfire_cli
3. **Flutter deps:** `cd apps/mobile && flutter pub get`
4. **Code generation:** `dart run build_runner build`
5. **Functions deps:** `cd functions && npm install`
6. **`.env` setup:** If `apps/mobile/.env` missing → copy from `.env.example`; then check `MAPBOX_ACCESS_TOKEN` and `USE_EMULATOR`; if MAPBOX token is empty, prompt:
   ```
   ⚠  MAPBOX_ACCESS_TOKEN is not set.
   Get a token at https://account.mapbox.com/access-tokens/
   Enter your Mapbox public access token (or press Enter to skip):
   ```
   Write non-empty answer into `.env`.
7. **Firebase setup:** If `apps/mobile/lib/firebase_options.dart` contains "TODO" → prompt:
   ```
   Firebase is not yet configured. You need a Firebase project.
   Enter your Firebase project ID (or press Enter to skip):
   ```
   If provided, run `cd apps/mobile && flutterfire configure --project=<id> --platforms=android,web --yes`
8. **Git hooks:** `git config core.hooksPath .githooks`
9. **Done:** print usage summary for `./dev.sh [--web|--prod|--emulator-only]`

---

### 11. `setup.ps1`

PowerShell equivalent of `setup.sh`:
- Same steps, PowerShell syntax
- Use `Write-Host` with `-ForegroundColor` for colors
- `Read-Host` for prompts
- Check commands with `Get-Command -ErrorAction SilentlyContinue`
- Run `flutter pub get`, `dart run build_runner build`, `npm install` via `&` operator
- Same `.env` and `firebase_options.dart` logic

---

### 12. `dev.sh`

Mirrors CozyTalk's `dev.sh` exactly in structure, adapted for frontline:

**Key differences from CozyTalk:**
- Title: `Frontline · dev runner`
- `.env` key: `MAPBOX_ACCESS_TOKEN` (not `GIPHY_API_KEY`)
- Flutter dart-defines: `--dart-define=MAPBOX_ACCESS_TOKEN=$MAPBOX_ACCESS_TOKEN --dart-define=USE_EMULATOR=true/false`
- Emulator ports: Auth 9099, Firestore 8080, Functions 5001, Storage 9199 (no RTDB 9000 — frontline uses Firestore only)
- `wait_for_port` checks: auth 9099, firestore 8080, functions 5001, storage 9199
- No Vertex AI ADC check (no interest matching in frontline)
- Functions build step before emulator start: `cd functions && npm run build`
- Same `emulators_already_up()` detect + attach pattern
- Same Java compatibility guard for Android

**Args:** `--prod | --web | --emulator-only | --help` (same as CozyTalk)

---

### 13. `dev.ps1`

PowerShell equivalent of `dev.sh`:
- Same args and flags
- Use `$env:MAPBOX_ACCESS_TOKEN`, `$env:USE_EMULATOR`
- TCP port check via `Test-NetConnection`
- Same emulator detect + attach logic
- Background job for emulators: `Start-Job`
- Same cleanup on `Ctrl+C` via `try/finally`

---

### 14. `CLAUDE.md`

Comprehensive project guide — adapted from CozyTalk's structure. Key sections:

1. **Pull Requests** — always use `.github/pull_request_template.md`
2. **Project** — privacy-first anonymous reporting, location fuzzing, GDELT wire news; Android + Web
3. **Tech stack table:**

| Concern | Choice |
|---|---|
| Framework | Flutter 3.41+ · Dart 3.x |
| State | Riverpod 3.x + `Notifier` pattern |
| Navigation | GoRouter 17.x + `AppRouter` |
| Backend | Firebase Auth (anonymous), Firestore, Storage, Cloud Functions v2 (TypeScript) |
| Maps | Mapbox Flutter SDK 2.x |
| Geo queries | geoflutterfire_plus |
| Models | Freezed + json_serializable |

4. **Architecture** — Clean Architecture, feature-first, same 3-layer diagram as CozyTalk
5. **Privacy rules (hard, non-negotiable):**
   - Location MUST be fuzzed ±3km before any Firestore write — always via `fuzzReportLocation` CF
   - No PII stored anywhere: reports are anonymous, no user identifiers tied to content
   - Firebase Anonymous Auth only — never prompt for name/email/phone
6. **Commands:**
   ```bash
   cd apps/mobile && flutter pub get && dart run build_runner build --delete-conflicting-outputs
   flutter test && flutter analyze
   firebase emulators:start
   ./dev.sh [--web|--prod|--emulator-only]
   .\dev.ps1 [...]   # Windows
   ```
7. **Features table** — auth, map, feed, reporting, my_reports with status = Stub
8. **Firestore schema** (stub section — to be filled in as schema is designed):
   - `reports/{id}` — fuzzed coords, media refs, category, timestamp, userId (anonymous UID)
   - `wire_news/{id}` — GDELT-sourced, written by CF
9. **Environment:** `USE_EMULATOR` dart-define (default `true`); `MAPBOX_ACCESS_TOKEN` dart-define
10. **Agent workflow** — architect, flutter-engineer, backend-engineer, qa-engineer, security-reviewer
11. **Conventional Commits** — same as CozyTalk
12. **Do Not Do** — no real coords in Firestore, no PII, no Firebase outside datasources, no business logic in Notifiers
13. **Agentic coding conventions** — update CLAUDE.md when architecture changes; run `flutter analyze` before every PR

---

### 15. `.claude/settings.json`

```json
{
  "permissions": {
    "allow": [
      "Bash(flutter test *)",
      "Bash(flutter analyze *)",
      "Bash(flutter pub get)",
      "Bash(dart run build_runner build*)",
      "Bash(npm install)",
      "Bash(npm run build)",
      "Bash(npm run build:watch)",
      "Bash(npm run lint *)",
      "Bash(npm test)",
      "Bash(npx tsc *)",
      "Bash(firebase emulators:start*)",
      "Bash(flutterfire configure*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "sh -c 'root=$(git rev-parse --show-toplevel 2>/dev/null || pwd); exec \"$root/.claude/hooks/enforce-pr-template.sh\"'"
          },
          {
            "type": "command",
            "command": "root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; lock=\"$root/.git/index.lock\"; [ -f \"$lock\" ] && ! lsof \"$lock\" >/dev/null 2>&1 && rm -f \"$lock\"; exit 0"
          },
          {
            "type": "command",
            "command": "cmd=$(jq -r '.tool_input.command'); if echo \"$cmd\" | grep -qE 'git push.*(origin )?(main|master)'; then echo '{\"decision\":\"block\",\"reason\":\"Direct push to main/master is not allowed. Create a branch and open a PR instead.\"}'; exit 2; fi"
          }
        ]
      }
    ]
  }
}
```

---

### 16. `.claude/agents/`

Five role files (adapted from CozyTalk):

**`architect.md`** — system design for frontline: Firestore schema (reports, wire_news), CF triggers (GDELT scheduler, location fuzzing callable), privacy-first decisions, GoRouter shell design

**`flutter-engineer.md`** — feature implementation; Mapbox integration patterns; GoRouter ShellRoute; Riverpod Notifier pattern; `auth` feature as canonical reference; hard rules (no Firebase outside datasources, no PII, always go through a use case)

**`backend-engineer.md`** — Cloud Functions (TypeScript): `fetchGdeltNews` (scheduled), `fuzzReportLocation` (callable); Firestore rules; Storage rules; GDELT API parsing; location fuzzing algorithm

**`qa-engineer.md`** — same fake-notifier test pattern as CozyTalk; quality gates; privacy audit checklist (no real coords in test data, no PII)

**`security-reviewer.md`** — privacy audit focus: location fuzzing enforcement, anonymous auth, Firestore rules, no PII leaks, Storage rules for media uploads

---

### 17. `.claude/hooks/`

Copy directly from CozyTalk and adapt:

**`enforce-pr-template.sh`** — same logic, updated section list to match frontline's template:
- `## Summary`, `## Type of Change`, `## Related Issues`, `## Changes`, `## Testing`, `## Privacy & Security Checklist`, `## Clean Architecture Checklist`, `## Screenshots / Recordings`, `## Notes for Reviewers`

**`enforce-authorship.sh`** — copy exactly from CozyTalk

---

### 18. `.claude/skills/`

Four skills:

**`github-pr-review/SKILL.md`** — copy exactly from CozyTalk (no project-specific content)

**`firebase-deploy/SKILL.md`**:
- Guided deploy workflow: `firebase deploy --only functions`, `--only firestore:rules`, `--only storage`
- Pre-deploy checklist: functions build passes, rules reviewed, emulator tests green
- Always confirm with `AskUserQuestion` before deploying to production

**`privacy-audit/SKILL.md`**:
- Scan for: direct `GeoPoint` writes without fuzzing, PII fields in Firestore models, hardcoded coords in tests, `firebase_auth.currentUser.email` references
- Check `fuzzReportLocation` CF is called on every report submission path
- Verify `firebase_options.dart` is gitignored
- Report findings with file:line references

**`feature-scaffold/SKILL.md`**:
- Ask for feature name (e.g. `notifications`)
- Generate full Clean Architecture skeleton: `domain/entities/`, `domain/repositories/`, `data/models/`, `data/datasources/`, `data/repositories/`, `presentation/providers/`, `presentation/screens/`
- Add GoRouter route stub
- Add feature entry to CLAUDE.md features table
- Run `dart run build_runner build` after generation

---

### 19. `.github/pull_request_template.md`

Adapted from CozyTalk's template, with frontline-specific checklists:

```markdown
## Summary
## Type of Change
## Related Issues
## Changes
## Testing
## Privacy & Security Checklist
- [ ] No real coordinates written to Firestore without fuzzing
- [ ] No PII collected or stored
- [ ] No Firebase SDK calls outside datasources/
- [ ] No secrets in committed files
- [ ] Firestore/Storage rules updated if applicable
## Clean Architecture Checklist
- [ ] Domain layer has zero Flutter/Firebase imports
- [ ] Business logic in UseCases, not Notifiers or Screens
- [ ] @freezed models regenerated via build_runner
## Screenshots / Recordings
## Notes for Reviewers
```

---

### 20. `PLAN.md` (repo root)

A copy of this plan lives at `~/Projects/frontline/PLAN.md` so all five developers can reference the project roadmap and setup rationale without needing access to the `.claude/plans/` folder. Content matches this document.

---

## Execution Order

1. Write `PLAN.md` at repo root (copy of this plan)
2. `flutter create apps/mobile --platforms android,web`
2. Delete default boilerplate; create assets dirs
3. Write `pubspec.yaml`, `analysis_options.yaml`, `.env.example`
4. Write all `lib/` files (main.dart → router → theme → utils → feature stubs → shared)
5. Write `functions/` skeleton (package.json, tsconfig.json, src/)
6. Write Firebase config files (firebase.json, rules stubs, .firebaserc)
7. Write `.gitignore`
8. Write `setup.sh` and `setup.ps1`
9. Write `dev.sh` and `dev.ps1`
10. Write `CLAUDE.md`
11. Write `.claude/settings.json`, agents (5 files), hooks (2 files), skills (4 dirs)
12. Write `.github/pull_request_template.md`
13. `chmod +x setup.sh dev.sh .claude/hooks/*.sh`
14. `cd apps/mobile && flutter pub get` — verify no resolution errors
15. `flutter analyze` — confirm zero issues

---

## Verification

1. `cd ~/Projects/frontline/apps/mobile && flutter pub get` — resolves cleanly
2. `flutter analyze` — zero issues
3. `flutter build apk --debug --dart-define=USE_EMULATOR=true --dart-define=MAPBOX_ACCESS_TOKEN=test` — compiles
4. `flutter build web --dart-define=USE_EMULATOR=true --dart-define=MAPBOX_ACCESS_TOKEN=test` — compiles
5. `dart run build_runner build` — no errors (stubs don't have generated code yet, but no failures)
6. `cd functions && npm install && npm run build` — TypeScript compiles cleanly
7. `./setup.sh` dry run confirms all prerequisites detected correctly
