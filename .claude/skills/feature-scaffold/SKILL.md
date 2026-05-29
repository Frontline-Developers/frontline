---
name: feature-scaffold
description: Generate a full Clean Architecture feature skeleton — domain entities, repositories, data models, datasources, Riverpod provider, and placeholder screen
allowed-tools: AskUserQuestion, Write, Bash, Read
---

# Feature Scaffold

## Overview

Generates a complete Clean Architecture feature skeleton for Frontline. Use when starting a new feature from scratch.

## Workflow

### Step 1: Gather requirements

Ask the user:
1. Feature name (snake_case, e.g. `notifications`)
2. What entities does this feature own? (e.g. `Notification` with fields id, title, body, createdAt)
3. Does it need a GoRouter route? If so, what path and is it inside or outside the bottom nav shell?
4. Does it depend on another feature's state? (e.g. needs `authNotifierProvider`)

### Step 2: Generate files

Create the following structure under `apps/mobile/lib/features/<name>/`:

```
<name>/
├── domain/
│   ├── entities/<name>.dart              ← plain Dart class, no imports
│   └── repositories/<name>_repository.dart  ← abstract interface
├── data/
│   ├── models/<name>_model.dart          ← fromJson + toEntity()
│   ├── datasources/<name>_datasource.dart  ← abstract + stub impl
│   └── repositories/<name>_repository_impl.dart
└── presentation/
    ├── providers/<name>_provider.dart    ← Notifier + State + sentinel copyWith
    └── screens/<name>_screen.dart        ← ConsumerWidget placeholder
```

### Step 3: Wire up router

Add a GoRoute to `apps/mobile/lib/core/router/app_router.dart`:
- Inside `ShellRoute.routes` if it's a tab screen
- At the top level if it's a full-screen overlay

### Step 4: Update CLAUDE.md

Add a row to the features table in `CLAUDE.md`:
```
| `<name>` | `<name>NotifierProvider` | Stub | <one-line description> |
```

### Step 5: Generate code

```bash
cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
```

### Step 6: Confirm

Show the user the list of files created and ask them to verify the feature entry in CLAUDE.md.

## File Templates

### Entity
```dart
class Foo {
  final String id;
  // ... fields
  const Foo({required this.id});
}
```

### Abstract repository
```dart
import '../entities/foo.dart';
abstract class FooRepository {
  Stream<List<Foo>> watchFoos();
}
```

### Notifier + State (with sentinel copyWith)
```dart
enum FooStatus { idle, loading, error }

class FooState {
  final List<Foo> items;
  final FooStatus status;
  final String? error;
  const FooState({this.items = const [], this.status = FooStatus.idle, this.error});

  FooState copyWith({List<Foo>? items, FooStatus? status, Object? error = _sentinel}) {
    return FooState(
      items: items ?? this.items,
      status: status ?? this.status,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}
const _sentinel = Object();

final fooNotifierProvider = NotifierProvider<FooNotifier, FooState>(FooNotifier.new);

class FooNotifier extends Notifier<FooState> {
  @override
  FooState build() => const FooState();
}
```

## Privacy Reminder

If the new feature handles user location or user-submitted content:
- Remind the user that location must go through `fuzzReportLocation` CF before Firestore write
- No PII fields in entities or models
- Run `/privacy-audit` after implementation
