# QA Report — main (9ad1e20)

**Date:** 2026-06-05  
**Scope:** All changes merged to main since `179eef5` — alerts feature, map expansion, pin lock screen  
**Test run:** 423/423 pass · `flutter analyze`: 0 issues · `tsc`: 0 errors

---

## Summary

| Severity | Count |
|---|---|
| Critical | 1 |
| High | 2 |
| Medium | 4 |
| Low | 3 |

---

## Critical

### C-1 — Missing Firestore rules for `user_alerts` and `user_tokens`
**File:** `firestore.rules:5-6`  
**Impact:** Alert subscriptions and FCM token registration fail with permission-denied in production. The alert feature is completely non-functional outside the emulator.

The catch-all deny rule covers every path not explicitly matched:
```
match /{document=**} {
  allow read, write: if false;
}
```

Neither `user_alerts/{userId}/subscriptions/{subId}` nor `user_tokens/{userId}` appear anywhere in the rules file. The datasources write to both:

- `alert_datasource_impl.dart:18-21` — writes `user_alerts/{userId}/subscriptions`
- `fcm_token_service.dart:39` — writes `user_tokens/{userId}`

The Cloud Function (`sendAlertNotifications`) also reads both collections server-side (admin SDK bypasses rules), so the CF itself works — but the client writes that feed it will always be denied.

**Fix:** Add rules for both collections:
```
match /user_alerts/{userId}/subscriptions/{subId} {
  allow create: if request.auth != null && request.auth.uid == userId;
  allow read:   if request.auth != null && request.auth.uid == userId;
  allow delete: if request.auth != null && request.auth.uid == userId;
}

match /user_tokens/{userId} {
  allow write: if request.auth != null && request.auth.uid == userId;
}
```

---

## High

### H-1 — Stream subscription leak in `MapNotifier.watchArea()`
**File:** `apps/mobile/lib/features/map/presentation/providers/map_provider.dart:104-121`  
**Impact:** Every call to `watchArea()` opens a new Firestore listener that is never closed. On tab switches, filter changes, or any re-invocation, listeners stack up, causing redundant Firestore reads, duplicate state emissions, and a memory leak that grows for the lifetime of the session.

```dart
void watchArea(double lat, double lng, double radiusKm) {
  state = state.copyWith(isLoading: true, error: null);
  ref.read(_mapRepositoryProvider)
     .watchReportsNear(...)
     .listen(               // ← StreamSubscription discarded
       (reports) => ...,
       onError: (e) => ...,
     );
}
```

**Fix:** Store the subscription and cancel on re-subscription:
```dart
StreamSubscription<List<MapReport>>? _sub;

void watchArea(double lat, double lng, double radiusKm) {
  _sub?.cancel();
  state = state.copyWith(isLoading: true, error: null);
  _sub = ref.read(_mapRepositoryProvider)
     .watchReportsNear(...)
     .listen(...);
}
```
Riverpod will call `dispose()` when the notifier is destroyed — cancel `_sub` there too, or use `ref.onDispose(() => _sub?.cancel())` in `build()`.

---

### H-2 — `PinNotifier._initialize()` has no error handling — app deadlocks on storage failure
**File:** `apps/mobile/lib/features/pin/presentation/providers/pin_provider.dart:32-51`  
**Impact:** If `FlutterSecureStorage.read()` throws (corrupted keystore, permissions revoked, first boot on some Android OEMs), `_initialize()` throws, the state stays at `PinStatus.loading`, and `main.dart:58` keeps rendering the spinner forever. The app is completely locked with no recovery path.

```dart
Future<void> _initialize() async {
  final repo = ref.read(pinRepositoryProvider);
  final status = await repo.getInitialStatus();     // ← throws → never reaches state update
  ...
  state = state.copyWith(status: status, ...);       // ← never reached
}
```

**Fix:** Wrap with try/catch and fall back to `createPin` so the user can always recover:
```dart
Future<void> _initialize() async {
  try {
    ...
    state = state.copyWith(status: status, ...);
  } catch (_) {
    state = state.copyWith(status: PinStatus.createPin);
  }
}
```

---

## Medium

### M-1 — `'anonymous'` UID fallback causes subscription collision
**File:** `apps/mobile/lib/features/map/presentation/screens/map_screen_bottom.dart:994-996`  
**Impact:** If anonymous auth has not yet completed when the user taps "Turn on alerts", the alert is saved under `userId = 'anonymous'`. Every unauthenticated user shares the same Firestore path `user_alerts/anonymous/subscriptions/...`, meaning:
- Subscriptions from different devices clobber each other's notification targets.
- `sendAlertNotifications` fetches the single `user_tokens/anonymous` token, sending alerts to whoever registered last.

```dart
final uid = ref.read(authNotifierProvider).user?.uid ?? 'anonymous';
```

**Fix:** Guard the save behind a real UID check. If auth is not ready, show an error or wait:
```dart
final uid = ref.read(authNotifierProvider).user?.uid;
if (uid == null) {
  // show snackbar: "Please wait, signing in..."
  return;
}
```

---

### M-2 — Raw exception message exposed to the UI
**File:** `apps/mobile/lib/features/alerts/presentation/providers/alert_provider.dart:87-88`  
**Impact:** On a Firestore permission-denied error (see C-1), the UI will display something like `[cloud_firestore/permission-denied] Missing or insufficient permissions.` This leaks internal error details and is not a user-friendly message.

```dart
} catch (e) {
  state = state.copyWith(status: AlertStatus.error, error: e.toString());
}
```

**Fix:** Sanitize before display, e.g. map `FirebaseException` codes to user-facing strings.

---

### M-3 — Sequential Firestore reads inside `for` loop in `sendAlertNotifications`
**File:** `functions/src/sendAlertNotifications.ts:59`  
**Impact:** For each matching subscription the function performs a sequential `await db.doc(...).get()` to fetch the FCM token. With N matching subscriptions this is O(N) sequential reads. Cloud Functions v2 default timeout is 60 seconds — a large subscriber base will cause the function to time out before all notifications are sent, silently dropping them.

```typescript
for (const subDoc of alertsSnap.docs) {
  ...
  const tokenDoc = await db.doc(`user_tokens/${sub.userId}`).get();  // sequential
  ...
}
```

**Fix:** Collect all token fetches first, then `Promise.all()` them, then build the sends list:
```typescript
const tokenFetches = alertsSnap.docs.map(doc =>
  db.doc(`user_tokens/${doc.data().userId}`).get()
);
const tokenDocs = await Promise.all(tokenFetches);
```

---

### M-4 — PIN stored as unsalted SHA-256
**File:** `apps/mobile/lib/features/pin/data/datasources/pin_datasource.dart:102`  
**Impact:** A 6-digit PIN has exactly 1,000,000 possible values. Unsalted SHA-256 means a pre-computed rainbow table covers the entire keyspace in milliseconds. On a rooted Android device where Keystore keys are extractable, an attacker who reads the secure storage can recover the PIN instantly.

```dart
String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();
```

The security boundary is the Android Keystore (which `flutter_secure_storage` uses), so practical risk is limited to rooted devices. However, the OWASP MASVS standard (L1) requires a salted, slow KDF (PBKDF2, bcrypt, argon2) for PIN/password storage.

**Fix:** Use PBKDF2 with a random per-device salt stored separately in secure storage, or at minimum prepend a stored random salt before hashing:
```dart
// Generate once, store in secure storage alongside the hash
final salt = base64.encode(List.generate(16, (_) => Random.secure().nextInt(256)));
final hash = sha256.convert(utf8.encode(salt + pin)).toString();
```

---

## Low

### L-1 — No retry path for anonymous sign-in failure
**File:** `apps/mobile/lib/main.dart:37-46`  
**Impact:** If `signInAnonymously()` fails on cold start (no network), the comment says "retries via AuthStateChanges" but there is no such retry wired up. The app renders but every Firestore read fails with permission-denied until the user manually restarts the app. A background retry or `onAuthStateChanged` listener that signs in when auth is null would self-heal.

---

### L-2 — Notification body truncated without ellipsis
**File:** `functions/src/sendAlertNotifications.ts:70`  
**Impact:** Minor UX — push notifications truncate the description at 120 characters with no indication to the user that the message was cut off.

```typescript
body: description?.slice(0, 120) ?? categoryLabel,
```

**Fix:**
```typescript
body: description && description.length > 120
  ? `${description.slice(0, 117)}...`
  : (description ?? categoryLabel),
```

---

### L-3 — `collectionGroup("subscriptions")` query has no Firestore index defined
**File:** `functions/src/sendAlertNotifications.ts:32` · `firestore.indexes.json`  
**Impact:** Firestore collection group queries require an explicit index. The `firestore.indexes.json` defines indexes for `reports` and `wire_news` but has no index for the `subscriptions` collection group. In production this will throw `FAILED_PRECONDITION: The query requires an index` on first invocation, silently killing all alert notifications.

**Fix:** Add to `firestore.indexes.json`:
```json
{
  "collectionGroup": "subscriptions",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" }
  ]
}
```

---

## Architecture / Standards Notes

These are not bugs but diverge from the project's own conventions.

| Location | Issue |
|---|---|
| `map_screen_bottom.dart:990-1006` | Alert save logic (UID read, category map, `save()` call) lives in the `onPressed` callback of a `StatefulWidget`. Per CLAUDE.md rule 3, business logic belongs in a domain `UseCase` or at minimum in the `Notifier`, not in a screen. |
| `alert_provider.dart:70` | `SaveAlert` usecase is instantiated inline inside `AlertNotifier.save()` rather than being injected via a provider. This breaks testability — you cannot override the usecase in tests without overriding the repository underneath it. |
| `pin_datasource.dart:79-82` | `getBiometricEnabled()` calls `SharedPreferences.getInstance()` on every read instead of using a cached instance or a `ref`-injected prefs provider. Minor but creates unnecessary async overhead on every PIN screen render. |

---

## Verdict

**Do not ship alerts in production until C-1 (Firestore rules) is fixed** — subscriptions will silently fail for every user. H-1 (stream leak) and H-2 (PIN deadlock) should also be addressed before the next release. The remaining issues are lower-risk but should be tracked.
