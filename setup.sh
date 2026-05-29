#!/usr/bin/env bash
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[38;5;82m'
CYAN='\033[38;5;39m'
YELLOW='\033[38;5;220m'
RED='\033[38;5;196m'
MAGENTA='\033[38;5;196m'
GRAY='\033[38;5;245m'

HR="${GRAY}$(printf '─%.0s' $(seq 1 60))${RESET}"

ok()   { printf "  ${GREEN}✓${RESET}  %b\n" "$*"; }
fail() { printf "  ${RED}✗${RESET}  %b\n" "$*"; exit 1; }
step() { printf "\n${BOLD}${CYAN}  ▸ %b${RESET}\n" "$*"; }
info() { printf "  ${GRAY}  %b${RESET}\n" "$*"; }
warn() { printf "  ${YELLOW}⚠${RESET}  %b\n" "$*"; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# ── Header ────────────────────────────────────────────────────────────────────
printf "\n"
printf "  ${MAGENTA}${BOLD}Frontline${RESET}  ${GRAY}·  project setup${RESET}\n"
printf "$HR\n\n"

# ── Prerequisites ─────────────────────────────────────────────────────────────
step "Checking prerequisites"

require() {
  local cmd="$1" label="${2:-$1}" hint="${3:-}"
  if command -v "$cmd" &>/dev/null; then
    local ver
    ver="$("$cmd" --version 2>&1 | head -1)"
    ok "${label}  ${GRAY}${ver}${RESET}"
  else
    fail "${label} not found${hint:+ — ${hint}}"
  fi
}

require flutter "flutter" "https://docs.flutter.dev/get-started/install"

DART_VER=$(dart --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
DART_MAJOR=$(printf '%s' "$DART_VER" | cut -d. -f1)
DART_MINOR=$(printf '%s' "$DART_VER" | cut -d. -f2)
if [[ "$DART_MAJOR" -lt 3 ]] || { [[ "$DART_MAJOR" -eq 3 ]] && [[ "$DART_MINOR" -lt 9 ]]; }; then
  fail "Dart $DART_VER is too old — sdk: ^3.9.0 required  ${GRAY}(run: flutter upgrade)${RESET}"
fi

require node "node" "Install Node.js 24+ from https://nodejs.org"
NODE_MAJOR=$(node --version | grep -oE '^v[0-9]+' | tr -d 'v')
if [[ "$NODE_MAJOR" -lt 24 ]]; then
  warn "Node $NODE_MAJOR detected — project targets Node 24 (package.json engines)"
  info "Upgrade: https://nodejs.org"
fi

require npm "npm"

if command -v java &>/dev/null; then
  JAVA_VER_LINE=$(java -version 2>&1 | head -1)
  ok "java  ${GRAY}${JAVA_VER_LINE}${RESET}"
  JAVA_MAJOR=$(printf '%s' "$JAVA_VER_LINE" | grep -oE '"[0-9]+' | tr -d '"' | head -1)
  [[ "$JAVA_MAJOR" -eq 1 ]] && JAVA_MAJOR=$(printf '%s' "$JAVA_VER_LINE" | grep -oE '"1\.[0-9]+' | cut -d. -f2)
  if [[ "$JAVA_MAJOR" -lt 21 ]]; then
    warn "Java $JAVA_MAJOR detected — Java 21+ required for Firebase emulators and Android builds"
    info "Install JDK 21+ from https://adoptium.net"
  fi
else
  warn "java not found — needed for Android builds and Firebase emulators"
  info "Install JDK 21+ from https://adoptium.net"
fi

if command -v firebase &>/dev/null; then
  ok "firebase  ${GRAY}$(firebase --version 2>&1 | head -1)${RESET}"
else
  warn "firebase-tools not installed globally"
  info "Run:  npm install -g firebase-tools"
fi

if command -v flutterfire &>/dev/null; then
  ok "flutterfire  ${GRAY}$(flutterfire --version 2>&1 | head -1)${RESET}"
else
  warn "flutterfire CLI not installed"
  info "Run:  dart pub global activate flutterfire_cli"
fi

# ── Flutter dependencies ──────────────────────────────────────────────────────
step "Flutter dependencies"
info "flutter pub get  →  apps/mobile"
(cd apps/mobile && flutter pub get)
ok "Flutter packages ready"

# ── Code generation ───────────────────────────────────────────────────────────
step "Code generation  ${GRAY}(Freezed + Riverpod)${RESET}"
info "build_runner build  →  apps/mobile"
(cd apps/mobile && dart run build_runner build --delete-conflicting-outputs)
ok "Generated code up to date"

# ── Cloud Functions ───────────────────────────────────────────────────────────
step "Cloud Functions dependencies"
info "npm install  →  functions/"
(cd functions && npm install --silent)
ok "Node packages ready"

# ── .env ──────────────────────────────────────────────────────────────────────
step ".env"
ENV_FILE="$ROOT_DIR/apps/mobile/.env"
ENV_EXAMPLE="$ROOT_DIR/apps/mobile/.env.example"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  ok "Created apps/mobile/.env  ${GRAY}(USE_EMULATOR=true)${RESET}"
else
  ok "apps/mobile/.env already exists"
fi

# Load .env
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^\s*# ]] && continue
    [[ "$line" =~ ^\s*$ ]] && continue
    if [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]]; then
      k="${BASH_REMATCH[1]}"
      v="${BASH_REMATCH[2]}"
      [[ -z "${!k:-}" ]] && export "$k=$v"
    fi
  done < "$ENV_FILE"
fi

if [[ -z "${MAPBOX_ACCESS_TOKEN:-}" ]]; then
  warn "MAPBOX_ACCESS_TOKEN is not set."
  info "Get a token at https://account.mapbox.com/access-tokens/"
  printf "\n  Enter your Mapbox public access token (or press Enter to skip): "
  read -r MAPBOX_TOKEN_INPUT
  if [[ -n "$MAPBOX_TOKEN_INPUT" ]]; then
    if grep -q '^MAPBOX_ACCESS_TOKEN=' "$ENV_FILE"; then
      sed -i "s|^MAPBOX_ACCESS_TOKEN=.*|MAPBOX_ACCESS_TOKEN=${MAPBOX_TOKEN_INPUT}|" "$ENV_FILE"
    else
      printf '\nMAPBOX_ACCESS_TOKEN=%s\n' "$MAPBOX_TOKEN_INPUT" >> "$ENV_FILE"
    fi
    ok "MAPBOX_ACCESS_TOKEN saved to apps/mobile/.env"
  else
    warn "Skipped — map rendering will not work until token is set"
  fi
  printf "\n"
else
  ok "MAPBOX_ACCESS_TOKEN set"
fi

# ── Firebase setup ────────────────────────────────────────────────────────────
step "Firebase configuration"
FIREBASE_OPTIONS="$ROOT_DIR/apps/mobile/lib/firebase_options.dart"

if grep -q 'TODO' "$FIREBASE_OPTIONS" 2>/dev/null; then
  warn "firebase_options.dart not configured."
  info "You need a Firebase project. Create one at https://console.firebase.google.com"
  printf "\n  Enter your Firebase project ID (or press Enter to skip): "
  read -r FIREBASE_PROJECT_ID
  if [[ -n "$FIREBASE_PROJECT_ID" ]]; then
    if command -v flutterfire &>/dev/null; then
      info "Running flutterfire configure…"
      (cd apps/mobile && flutterfire configure \
        --project="$FIREBASE_PROJECT_ID" \
        --platforms=android,web \
        --yes 2>&1) && ok "Firebase configured" || warn "flutterfire configure failed — run manually"
    else
      warn "flutterfire CLI not found — configure manually:"
      info "dart pub global activate flutterfire_cli"
      info "cd apps/mobile && flutterfire configure --project=${FIREBASE_PROJECT_ID} --platforms=android,web"
      sed -i "s|TODO-your-project-id|${FIREBASE_PROJECT_ID}|g" "$ROOT_DIR/.firebaserc"
      ok "Updated .firebaserc with project ID"
    fi
  else
    warn "Skipped — emulators will still work for local dev (USE_EMULATOR=true)"
  fi
  printf "\n"
else
  ok "firebase_options.dart already configured"
fi

# ── Git hooks ─────────────────────────────────────────────────────────────────
step "Git hooks"
if [[ -d "$ROOT_DIR/.githooks" ]]; then
  git config core.hooksPath .githooks
  ok "Git hooks active  ${GRAY}(.githooks/)${RESET}"
else
  info "No .githooks/ directory — skipping"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
printf "\n$HR\n\n"
printf "  ${GREEN}${BOLD}Setup complete.${RESET}\n\n"
printf "  ${BOLD}What to do next${RESET}\n\n"
printf "  ${CYAN}▸${RESET}  ${BOLD}./dev.sh${RESET}              Emulators + Flutter on Android\n"
printf "  ${CYAN}▸${RESET}  ${BOLD}./dev.sh --web${RESET}        Emulators + Flutter on Chrome\n"
printf "  ${CYAN}▸${RESET}  ${BOLD}./dev.sh --prod${RESET}       Flutter → ${YELLOW}live${RESET} Firebase (Android)\n"
printf "  ${CYAN}▸${RESET}  ${BOLD}./dev.sh --prod --web${RESET} Flutter → ${YELLOW}live${RESET} Firebase (Chrome)\n"
printf "\n"
printf "  ${GRAY}Emulator UI  →  http://127.0.0.1:4000${RESET}\n"
printf "  ${GRAY}Auth :9099   Firestore :8080   Functions :5001   Storage :9199${RESET}\n"
printf "\n"
