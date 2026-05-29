---
name: privacy-audit
description: Scan the codebase for privacy violations — raw coordinates in Firestore, PII fields, missing location fuzz calls, hardcoded secrets
allowed-tools: Bash, Read
---

# Privacy Audit

## Overview

Scans Frontline's codebase for privacy violations. The most critical checks are around location fuzzing and PII storage. Run before any PR that touches reporting, auth, data models, or Firestore rules.

## What to Scan

### 1. Raw Coordinates in Firestore (critical)

Check that `GeoPoint` is never constructed from user-supplied raw coordinates outside of the `fuzzReportLocation` CF response:

```bash
# Find GeoPoint usages in Flutter code
grep -rn "GeoPoint(" apps/mobile/lib/ --include="*.dart"
```

Every `GeoPoint(...)` in `apps/mobile/lib/` must use coordinates that came from the `fuzzReportLocation` CF response, never directly from the device location sensor.

### 2. PII Fields in Data Models

```bash
# Look for PII field names in Dart models and TypeScript CFs
grep -rn -i "email\|phone\|name\|displayName\|ip_address\|address" \
  apps/mobile/lib/features/ functions/src/ --include="*.dart" --include="*.ts"
```

Flag any matches that are being written to Firestore or Storage. `userId` (anonymous UID) is allowed. `email`, `displayName`, `phone` are not.

### 3. Missing fuzzReportLocation Call

```bash
# Check reporting datasource calls the CF
grep -n "fuzzReportLocation\|submitReport" \
  apps/mobile/lib/features/reporting/data/datasources/reporting_datasource.dart
```

The `submitReport` implementation must call `fuzzReportLocation` before any Firestore write.

### 4. Firebase Auth Email/DisplayName Usage

```bash
grep -rn "currentUser\.email\|currentUser\.displayName\|currentUser\.phoneNumber" \
  apps/mobile/lib/ --include="*.dart"
```

These should never appear outside of `auth_datasource.dart`, and only for anonymous auth (where they are null anyway).

### 5. Hardcoded Secrets / Tokens

```bash
# Look for anything that looks like a token or API key hardcoded in source
grep -rn "pk\.\|sk\.\|AIza\|AAAA\|token\s*=\s*['\"]" \
  apps/mobile/lib/ functions/src/ --include="*.dart" --include="*.ts" | \
  grep -v '// ' | grep -v 'fromEnvironment'
```

Tokens must come from `dart-define` or environment variables, never hardcoded.

### 6. gitignore Check

```bash
# Confirm sensitive files are gitignored
git status --short | grep -E "google-services|GoogleService-Info|firebase_options|\.env$"
```

If any of these files appear in `git status` as untracked or staged, they must be added to `.gitignore` immediately.

### 7. Firestore Rules Default Deny

```bash
grep -A2 'match /{document=\*\*}' firestore.rules
```

Must show `allow read, write: if false;` as the catch-all.

## Report Format

Report findings as:

```
CRITICAL — <file>:<line>: <description>
WARNING  — <file>:<line>: <description>
OK       — <check name>: passed
```

Findings rated CRITICAL must be fixed before merge. WARNING should be reviewed by the architect.

## When to Run

- Before any PR touching `reporting`, `auth`, data models, or Firebase rules
- Before any production deploy
- On demand via `/privacy-audit`
