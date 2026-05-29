---
name: firebase-deploy
description: Guided deploy to Firebase — functions, Firestore rules, and Storage rules with pre-deploy checks and user confirmation
allowed-tools: AskUserQuestion, Bash
---

# Firebase Deploy

## Overview

Guided workflow for deploying Frontline's Firebase resources safely. Always confirms with the user before touching production.

**CRITICAL: Always get explicit user approval before deploying to production.**

## What This Skill Deploys

| Resource | Command | When to deploy |
|---|---|---|
| Cloud Functions | `firebase deploy --only functions` | After any change to `functions/src/` |
| Firestore rules | `firebase deploy --only firestore:rules` | After any change to `firestore.rules` |
| Firestore indexes | `firebase deploy --only firestore:indexes` | After any change to `firestore.indexes.json` |
| Storage rules | `firebase deploy --only storage` | After any change to `storage.rules` |

## Pre-Deploy Checklist (run before every deploy)

1. **Functions build passes:**
   ```bash
   cd functions && npm run build
   ```

2. **Emulator tests green:**
   ```bash
   ./dev.sh --emulator-only   # Terminal 1
   cd functions && npm test    # Terminal 2
   ```

3. **Flutter analyze zero issues:**
   ```bash
   cd apps/mobile && flutter analyze
   ```

4. **Security review:** For any rules change, invoke the `security-reviewer` agent first.

5. **`.firebaserc` has the correct project ID** (not the TODO placeholder).

## Workflow

1. Run pre-deploy checks
2. Show the user exactly what will be deployed and to which project
3. Ask for confirmation via `AskUserQuestion`
4. Deploy only after explicit approval
5. Verify deployment succeeded

## Example Approval Prompt

```
I'm about to deploy:
  - Cloud Functions (fuzzReportLocation, fetchGdeltNews)

Target project: your-project-id (production)

Pre-deploy checks:
  ✓ npm run build — clean
  ✓ npm test — 0 failures
  ✓ firebase_options.dart configured

Ready to deploy?
```

## Post-Deploy Verification

After deploying functions, test the callable in the emulator UI or via:
```bash
# Verify fuzzReportLocation is responding
firebase functions:shell
> fuzzReportLocation({lat: 40.7128, lng: -74.0060})
```

## Safety Rules

- Never deploy with `--force` flag
- Never deploy from an uncommitted state (run `git status` first)
- Never deploy rules that haven't been reviewed by `security-reviewer` agent
- If `.firebaserc` still contains `TODO-your-project-id`, stop and configure Firebase first
