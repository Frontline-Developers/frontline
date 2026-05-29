## Summary

<!-- One paragraph: what changed and why. Link the motivation, not just the diff. -->

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that changes existing behavior)
- [ ] Refactor (no behavior change, improves structure or readability)
- [ ] Chore (dependency update, config, CI, tooling)
- [ ] Docs

## Related Issues

<!-- Closes #<issue>, Fixes #<issue>, or N/A -->

Closes #

## Changes

<!-- Bullet list of what was added, changed, or removed. Be specific. -->

-
-

## Testing

<!-- Describe what you tested and how. -->

**Manual steps to verify:**

1.
2.

**Test coverage:**

- [ ] Unit tests added / updated
- [ ] Widget tests added / updated
- [ ] Tested on Android
- [ ] Tested on Web (Chrome)

## Privacy & Security Checklist

<!-- Required for any PR touching auth, reporting, Firestore rules, Storage rules, or Cloud Functions -->

- [ ] No real coordinates written to Firestore without going through `fuzzReportLocation` CF
- [ ] No PII collected or stored (no name, email, phone, IP)
- [ ] No Firebase SDK calls outside `datasources/` files
- [ ] No secrets or API keys added to tracked files
- [ ] Firestore / Storage security rules updated (if applicable)
- [ ] `firebase_options.dart`, `.env`, `google-services.json` remain gitignored

## Clean Architecture Checklist

- [ ] Domain layer has zero Flutter / Firebase imports
- [ ] Business logic lives in domain layer, not Notifiers or Screens
- [ ] New `@freezed` models ran through `build_runner` (if applicable)
- [ ] No unbounded `ListView(children: [...])` for dynamic data
- [ ] `flutter analyze` passes with zero issues

## Screenshots / Recordings

<!-- UI changes: before/after screenshots or a short screen recording. Delete section if not applicable. -->

| Before | After |
|--------|-------|
|        |       |

## Notes for Reviewers

<!-- Anything the reviewer should know: gotchas, follow-up tickets, intentional trade-offs. -->
