#!/usr/bin/env bash
set -euo pipefail

ok()   { printf "  [+]  %s\n" "$*"; }
fail() { printf "  [x]  %s\n" "$*" >&2; exit 1; }
log()  { printf "  >>  %s\n" "$*"; }
info() { printf "       %s\n" "$*"; }
warn() { printf "  [!]  %s\n" "$*"; }
hr()   { printf "  %s\n" "$(printf '%0.s-' {1..57})"; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# -- Args ----------------------------------------------------------------------
USE_PROD=false
USE_WEB=false
EMULATOR_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --prod)          USE_PROD=true ;;
    --web)           USE_WEB=true ;;
    --emulator-only) EMULATOR_ONLY=true ;;
    --help|-h)
      printf "\n"
      printf "  Usage: ./dev.sh [--prod] [--web] [--emulator-only]\n\n"
      printf "  --prod           Connect to live Firebase instead of local emulators\n"
      printf "  --web            Run on Chrome instead of Android\n"
      printf "  --emulator-only  Start Firebase emulators only -- no Flutter (for integration tests)\n\n"
      printf "  Without flags: emulator mode, Flutter will ask which device\n\n"
      exit 0
      ;;
    *) fail "Unknown argument: $arg  (try --help)" ;;
  esac
done

if $EMULATOR_ONLY && $USE_PROD; then
  fail "--emulator-only and --prod are mutually exclusive"
fi

# -- Header --------------------------------------------------------------------
printf "\n"
printf "  Frontline  -  dev runner\n"
hr
printf "\n"

if $EMULATOR_ONLY; then PLATFORM="none (emulator-only)"
elif $USE_WEB;     then PLATFORM="Chrome"
else                    PLATFORM="auto-detect"
fi
if $USE_PROD; then BACKEND="Production Firebase"
else               BACKEND="Local emulators"
fi

printf "  Platform  %s\n" "$PLATFORM"
printf "  Backend   %s\n" "$BACKEND"
printf "\n"

if $USE_PROD; then
  warn "You are connecting to live Firebase -- real data, real users."
  printf "\n"
fi

# -- Helpers -------------------------------------------------------------------
stop_process_on_port() {
  local port="$1"
  # lsof not available everywhere; fuser is more portable on Linux
  if command -v fuser &>/dev/null; then
    fuser -k "${port}/tcp" 2>/dev/null || true
  elif command -v lsof &>/dev/null; then
    local pids
    pids=$(lsof -ti:"$port" 2>/dev/null) && kill -9 $pids 2>/dev/null || true
  fi
}

test_port() {
  (echo > /dev/tcp/127.0.0.1/"$1") 2>/dev/null
}

emulators_up() {
  for port in 9099 8080 5001 9199; do
    test_port "$port" || return 1
  done
  return 0
}

# -- Emulator state ------------------------------------------------------------
EMULATOR_PID=""
LOG_FILE=""
EXIT_CODE=0
CLEANUP_DONE=false

stop_emulators() {
  $CLEANUP_DONE && return
  CLEANUP_DONE=true
  if [[ -n "$EMULATOR_PID" ]] && kill -0 "$EMULATOR_PID" 2>/dev/null; then
    printf "\n  Stopping emulators...\n"
    kill "$EMULATOR_PID" 2>/dev/null || true
    wait "$EMULATOR_PID" 2>/dev/null || true
    for port in 9099 8080 5001 9199 4000 4400 4500; do
      stop_process_on_port "$port"
    done
  elif $EMULATOR_ONLY; then
    printf "\n  Stopping emulators...\n"
    for port in 9099 8080 5001 9199 4000 4400 4500; do
      stop_process_on_port "$port"
    done
  fi
  if [[ -n "$LOG_FILE" ]]; then
    printf "  Session log saved -> %s\n" "$LOG_FILE"
  fi
  printf "  Done.\n\n"
}

show_emulator_tail() {
  if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
    tail -20 "$LOG_FILE" | sed 's/^/    /'
  fi
}

abort() {
  printf "\n  [x]  %s\n\n" "$*" >&2
  exit 1
}

# -- Load .env from apps/mobile ------------------------------------------------
ENV_FILE="$ROOT_DIR/apps/mobile/.env"
ENV_EXAMPLE="$ROOT_DIR/apps/mobile/.env.example"

if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$ENV_EXAMPLE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    warn "apps/mobile/.env not found -- created from .env.example"
    info "Open apps/mobile/.env and set your MAPBOX_ACCESS_TOKEN, then re-run."
    printf "\n"
  fi
fi

if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^\s*# || "$line" =~ ^\s*$ ]] && continue
    if [[ "$line" =~ ^([A-Z_]+)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
      k="${BASH_REMATCH[1]}"
      v="${BASH_REMATCH[2]}"
      v="${v%$'\r'}"
      [[ -z "${!k:-}" ]] && export "$k=$v"
    fi
  done < "$ENV_FILE"
fi

if [[ -z "${MAPBOX_ACCESS_TOKEN:-}" ]]; then
  warn "MAPBOX_ACCESS_TOKEN is not set -- map rendering will not work."
  info "Get a token at https://account.mapbox.com/ and add it to apps/mobile/.env"
  printf "\n"
fi

# -- Build Flutter args --------------------------------------------------------
FLUTTER_ARGS=()
$USE_WEB  && FLUTTER_ARGS+=("-d" "chrome")
$USE_PROD && FLUTTER_ARGS+=("--dart-define=USE_EMULATOR=false")
[[ -n "${MAPBOX_ACCESS_TOKEN:-}" ]] && FLUTTER_ARGS+=("--dart-define=MAPBOX_ACCESS_TOKEN=$MAPBOX_ACCESS_TOKEN")

# -- Emulator startup ----------------------------------------------------------
if ! $USE_PROD; then
  trap 'EXIT_CODE=$?; stop_emulators; exit $EXIT_CODE' EXIT
  trap 'stop_emulators; exit 130' INT TERM

  if emulators_up; then
    ok "Emulators already running -- attaching"
    info "Emulator UI -> http://127.0.0.1:4000"
    printf "\n"
    hr
  else
    for port in 9099 8080 5001 9199 4000 4400 4500; do
      stop_process_on_port "$port"
    done

    mkdir -p "$ROOT_DIR/logs"
    LOG_FILE="$ROOT_DIR/logs/emulator-$(date +%Y-%m-%d_%H-%M-%S).log"

    # Rotate: keep last 10 emulator session logs
    ls -t "$ROOT_DIR/logs"/emulator-20*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

    log "Building Cloud Functions..."
    if ! npm --prefix "$ROOT_DIR/functions" run build >> "$LOG_FILE" 2>&1; then
      printf "\n  [x]  Build failed. Last log:\n\n" >&2
      show_emulator_tail
      abort "Build failed"
    fi
    ok "Functions built"

    log "Starting Firebase emulators..."
    info "Session log -> $LOG_FILE"
    info "Emulator UI -> http://127.0.0.1:4000"
    printf "\n"

    firebase emulators:start --only functions,auth,firestore,storage >> "$LOG_FILE" 2>&1 &
    EMULATOR_PID=$!

    MAX_WAIT=90

    wait_for_port() {
      local name="$1" port="$2" elapsed=0
      printf "  Waiting for %s emulator on :%s" "$name" "$port"
      while ! test_port "$port"; do
        printf "."
        sleep 1
        elapsed=$((elapsed + 1))
        if [[ $elapsed -ge $MAX_WAIT ]]; then
          printf "\n  [x]  %s emulator didn't respond after %ss.\n  Last log lines:\n\n" "$name" "$MAX_WAIT" >&2
          show_emulator_tail
          abort "$name emulator timed out"
        fi
        if ! kill -0 "$EMULATOR_PID" 2>/dev/null; then
          printf "\n  [x]  Emulator process exited unexpectedly.\n  Last log lines:\n\n" >&2
          show_emulator_tail
          abort "Emulator process exited unexpectedly"
        fi
      done
      printf " ready\n"
    }

    wait_for_port "auth"      9099
    wait_for_port "firestore" 8080
    wait_for_port "functions" 5001
    wait_for_port "storage"   9199
    ok "Emulator UI -> http://127.0.0.1:4000"
    printf "\n"
    hr
  fi
fi

# -- Emulator-only mode --------------------------------------------------------
if $EMULATOR_ONLY; then
  printf "\n"
  ok "Emulators ready"
  info "Example: cd functions && npm test"
  printf "\n"
  hr
  printf "\n  Press Ctrl+C to stop emulators.\n\n"
  if [[ -n "$EMULATOR_PID" ]]; then
    wait "$EMULATOR_PID"
  else
    while true; do sleep 3600; done
  fi
  exit 0
fi

# -- Java compatibility guard (Android/Gradle only) ----------------------------
if ! $USE_WEB; then
  if command -v java &>/dev/null; then
    _ver=$(java -version 2>&1 | awk -F '"' 'NR==1 {split($2,a,"."); print (a[1]=="1"?a[2]:a[1])}')
    if [[ "$_ver" =~ ^[0-9]+$ ]] && (( _ver > 21 )); then
      _candidate=""
      # macOS: /usr/libexec/java_home resolves installed JDKs by version
      if [[ "$(uname -s)" == "Darwin" ]] && [[ -x /usr/libexec/java_home ]]; then
        for _v in 21 20 19 18 17 16 15 14 13 12 11; do
          _try=$(/usr/libexec/java_home -v "$_v" 2>/dev/null) || true
          if [[ -n "$_try" && -x "$_try/bin/java" ]]; then
            _candidate="$_try"
            break
          fi
        done
      fi
      # Linux (and macOS fallback): scan common install dirs
      if [[ -z "$_candidate" ]]; then
        for _v in 21 20 19 18 17 16 15 14 13 12 11; do
          for _dir in \
            "/usr/lib/jvm/java-${_v}-openjdk" \
            "/usr/lib/jvm/java-${_v}-openjdk-amd64" \
            "/usr/lib/jvm/java-${_v}-openjdk-arm64" \
            "/usr/lib/jvm/java-${_v}" \
            "/usr/lib/jvm/temurin-${_v}" \
            "/usr/local/lib/jvm/java-${_v}" \
            "/Library/Java/JavaVirtualMachines/temurin-${_v}.jdk/Contents/Home" \
            "/Library/Java/JavaVirtualMachines/jdk-${_v}.jdk/Contents/Home" \
            "/Library/Java/JavaVirtualMachines/jdk${_v}.jdk/Contents/Home"; do
            [[ -x "${_dir}/bin/java" ]] && _candidate="$_dir" && break 2
          done
        done
      fi
      if [[ -z "$_candidate" ]]; then
        abort "Java ${_ver} is not supported by the Kotlin Gradle plugin (max: 21).\nInstall any JDK between 11 and 21 and re-run, or set JAVA_HOME manually."
      fi
      export JAVA_HOME="$_candidate"
      warn "Java ${_ver} detected -- using ${_candidate} for Gradle"
      printf "\n"
    fi
  fi
fi

# -- Flutter -------------------------------------------------------------------
printf "\n"
web_suffix=""
$USE_WEB && web_suffix=" on Chrome"
log "Starting Flutter${web_suffix}..."
printf "\n"
hr
printf "\n"

cd apps/mobile
flutter run "${FLUTTER_ARGS[@]}"
