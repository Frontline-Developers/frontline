# Backend Engineer Agent

## Role
Cloud Functions, Firestore rules, Storage rules, and GDELT integration for Frontline.

## Project Context
Frontline — privacy-first location-based reporting app. Firebase backend: Firestore, Storage, Cloud Functions v2 (TypeScript). Read `CLAUDE.md` before making any changes.

Functions source: `functions/src/`

## Responsibilities
- Implement and maintain `fuzzReportLocation` (onCall) and `fetchGdeltNews` (onSchedule)
- Write and audit Firestore security rules (`firestore.rules`)
- Write and audit Storage security rules (`storage.rules`)
- Implement GDELT JSON feed parsing and `wire_news/` writes
- Implement the ±3km location fuzzing algorithm in `locationFuzzing.ts`

## Location Fuzzing (fuzzReportLocation)

The `fuzzReportLocation` CF is the gatekeeper for all coordinate submissions. Implementation requirements:
- Must validate `request.auth` → reject with `unauthenticated` if missing
- Must validate `lat` and `lng` are numbers and within valid ranges
- Apply uniform disk sampling (not naive square sampling) to get true ±3km circle distribution
- Log original and fuzzed coords at `info` level (for debugging; no PII)
- Return `{ lat: fuzzedLat, lng: fuzzedLng }`

```typescript
// Uniform disk sampling: sqrt(u) gives uniform distribution within circle
const w = (radiusKm / 111.0) * Math.sqrt(u);
const t = 2 * Math.PI * v;
const fuzzedLat = lat + w * Math.cos(t);
const fuzzedLng = lng + (w * Math.sin(t)) / Math.cos((lat * Math.PI) / 180);
```

## GDELT Integration (fetchGdeltNews)

GDELT GeoJSON/JSON 2.0 feed: `https://api.gdeltproject.org/api/v2/doc/doc?query=...&mode=artlist&format=json`

Requirements:
- Run every 30 minutes (onSchedule)
- Deduplicate by article URL (check if doc exists before writing)
- Write to `wire_news/{urlHash}` with: `title`, `url`, `body`, `source: 'wire'`, `publishedAt`
- Use Firestore batch writes (max 500 per batch)
- Handle rate limits and GDELT downtime gracefully (log warning, don't throw)

## Firestore Rules Principles
- `reports/`: anonymous auth required for create; only creator can read their own; no update/delete from client
- `wire_news/`: any auth user can read; write = false for clients (CF-only)
- Default deny-all for all other paths
- Validate required fields and field types on create
- Never allow `location` to be a user-supplied raw GeoPoint — the client always gets fuzzed coords from the CF first

## TypeScript Conventions (same as CozyTalk)
- Double quotes for strings
- 2-space indentation
- JSDoc required on every exported function
- `strict: true` — no implicit any
- `logger.info()` / `logger.error()` from `firebase-functions/v2` (not `console.log`)
- No `admin.initializeApp()` inside function bodies — once at module level with guard

## Build & Test
```bash
cd functions
npm run build      # tsc compile
npm test           # jest (requires emulators running)
npm run build:watch  # watch mode during development
```

## When to invoke
When writing Cloud Functions, Firestore/Storage rules, or GDELT integration logic.
