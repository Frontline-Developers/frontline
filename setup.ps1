# Frontline — project setup (Windows PowerShell)
# Run with: .\setup.ps1
# Requires PowerShell 5.1+ or PowerShell Core (pwsh)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Write-Ok($msg)   { Write-Host "  ✓  $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  ✗  $msg" -ForegroundColor Red; exit 1 }
function Write-Step($msg) { Write-Host "`n  ▸  $msg" -ForegroundColor Cyan }
function Write-Info($msg) { Write-Host "     $msg" -ForegroundColor DarkGray }
function Write-Warn($msg) { Write-Host "  ⚠  $msg" -ForegroundColor Yellow }
function Write-Hr        { Write-Host ("─" * 60) -ForegroundColor DarkGray }

Write-Host ""
Write-Host "  Frontline  ·  project setup" -ForegroundColor Magenta
Write-Hr
Write-Host ""

# ── Prerequisites ─────────────────────────────────────────────────────────────
Write-Step "Checking prerequisites"

function Require-Command($cmd, $label, $hint) {
  if (Get-Command $cmd -ErrorAction SilentlyContinue) {
    $ver = (& $cmd --version 2>&1 | Select-Object -First 1)
    Write-Ok "$label  $ver"
  } else {
    Write-Fail "$label not found${hint}"
  }
}

Require-Command flutter flutter " — https://docs.flutter.dev/get-started/install"

$dartVer = (dart --version 2>&1 | Select-Object -First 1) -replace '.*?(\d+\.\d+\.\d+).*','$1'
$dartParts = $dartVer.Split('.')
if ([int]$dartParts[0] -lt 3 -or ([int]$dartParts[0] -eq 3 -and [int]$dartParts[1] -lt 9)) {
  Write-Fail "Dart $dartVer is too old — sdk: ^3.9.0 required (run: flutter upgrade)"
}

Require-Command node node " — Install Node.js 24+ from https://nodejs.org"
$nodeMajor = (node --version) -replace 'v(\d+).*','$1'
if ([int]$nodeMajor -lt 24) {
  Write-Warn "Node $nodeMajor detected — project targets Node 24"
  Write-Info "Upgrade: https://nodejs.org"
}

Require-Command npm npm

if (Get-Command java -ErrorAction SilentlyContinue) {
  $javaVer = java -version 2>&1 | Select-Object -First 1
  Write-Ok "java  $javaVer"
} else {
  Write-Warn "java not found — needed for Android builds and Firebase emulators"
  Write-Info "Install JDK 21+ from https://adoptium.net"
}

if (Get-Command firebase -ErrorAction SilentlyContinue) {
  $fbVer = firebase --version 2>&1 | Select-Object -First 1
  Write-Ok "firebase  $fbVer"
} else {
  Write-Warn "firebase-tools not installed globally"
  Write-Info "Run: npm install -g firebase-tools"
}

if (Get-Command flutterfire -ErrorAction SilentlyContinue) {
  Write-Ok "flutterfire"
} else {
  Write-Warn "flutterfire CLI not installed"
  Write-Info "Run: dart pub global activate flutterfire_cli"
}

# ── Flutter dependencies ──────────────────────────────────────────────────────
Write-Step "Flutter dependencies"
Write-Info "flutter pub get  →  apps/mobile"
Push-Location apps/mobile
& flutter pub get
Pop-Location
Write-Ok "Flutter packages ready"

# ── Code generation ───────────────────────────────────────────────────────────
Write-Step "Code generation (Freezed + Riverpod)"
Write-Info "build_runner build  →  apps/mobile"
Push-Location apps/mobile
& dart run build_runner build --delete-conflicting-outputs
Pop-Location
Write-Ok "Generated code up to date"

# ── Cloud Functions ───────────────────────────────────────────────────────────
Write-Step "Cloud Functions dependencies"
Write-Info "npm install  →  functions/"
Push-Location functions
& npm install --silent
Pop-Location
Write-Ok "Node packages ready"

# ── .env ──────────────────────────────────────────────────────────────────────
Write-Step ".env"
$envFile    = Join-Path $Root "apps\mobile\.env"
$envExample = Join-Path $Root "apps\mobile\.env.example"

if (-not (Test-Path $envFile)) {
  Copy-Item $envExample $envFile
  Write-Ok "Created apps/mobile/.env"
} else {
  Write-Ok "apps/mobile/.env already exists"
}

# Parse .env
$envVars = @{}
Get-Content $envFile | ForEach-Object {
  if ($_ -match '^\s*([A-Z_]+)=(.*)$') {
    $envVars[$matches[1]] = $matches[2]
  }
}

if ([string]::IsNullOrEmpty($envVars['MAPBOX_ACCESS_TOKEN'])) {
  Write-Warn "MAPBOX_ACCESS_TOKEN is not set."
  Write-Info "Get a token at https://account.mapbox.com/access-tokens/"
  $token = Read-Host "  Enter your Mapbox public access token (or press Enter to skip)"
  if (-not [string]::IsNullOrEmpty($token)) {
    $content = Get-Content $envFile
    $content = $content -replace '^MAPBOX_ACCESS_TOKEN=.*', "MAPBOX_ACCESS_TOKEN=$token"
    if ($content -notmatch 'MAPBOX_ACCESS_TOKEN=') {
      $content += "`nMAPBOX_ACCESS_TOKEN=$token"
    }
    $content | Set-Content $envFile
    Write-Ok "MAPBOX_ACCESS_TOKEN saved to apps/mobile/.env"
  } else {
    Write-Warn "Skipped — map rendering will not work until token is set"
  }
} else {
  Write-Ok "MAPBOX_ACCESS_TOKEN set"
}

# ── Firebase setup ────────────────────────────────────────────────────────────
Write-Step "Firebase configuration"
$firebaseOptions = Join-Path $Root "apps\mobile\lib\firebase_options.dart"

if (Select-String -Path $firebaseOptions -Pattern 'TODO' -Quiet) {
  Write-Warn "firebase_options.dart not configured."
  Write-Info "Create a Firebase project at https://console.firebase.google.com"
  $projectId = Read-Host "  Enter your Firebase project ID (or press Enter to skip)"
  if (-not [string]::IsNullOrEmpty($projectId)) {
    if (Get-Command flutterfire -ErrorAction SilentlyContinue) {
      Write-Info "Running flutterfire configure…"
      Push-Location apps/mobile
      & flutterfire configure --project=$projectId --platforms=android,web --yes
      Pop-Location
      Write-Ok "Firebase configured"
    } else {
      Write-Warn "flutterfire CLI not found — configure manually:"
      Write-Info "dart pub global activate flutterfire_cli"
      Write-Info "cd apps/mobile; flutterfire configure --project=$projectId --platforms=android,web"
      (Get-Content "$Root\.firebaserc") -replace 'TODO-your-project-id', $projectId |
        Set-Content "$Root\.firebaserc"
      Write-Ok "Updated .firebaserc with project ID"
    }
  } else {
    Write-Warn "Skipped — emulators will still work with USE_EMULATOR=true"
  }
} else {
  Write-Ok "firebase_options.dart already configured"
}

# ── Git hooks ─────────────────────────────────────────────────────────────────
Write-Step "Git hooks"
& git config core.hooksPath .githooks
Write-Ok "pre-commit hook active  (dart format + prettier auto-fix; flutter analyze + eslint gate)"
Write-Ok "pre-push hook active    (flutter test + pubspec.lock check + functions lint + tsc)"

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Hr
Write-Host ""
Write-Host "  Setup complete." -ForegroundColor Green
Write-Host ""
Write-Host "  What to do next" -ForegroundColor White
Write-Host ""
Write-Host "  ▸  .\dev.ps1              Emulators + Flutter on Android" -ForegroundColor Cyan
Write-Host "  ▸  .\dev.ps1 --web        Emulators + Flutter on Chrome" -ForegroundColor Cyan
Write-Host "  ▸  .\dev.ps1 --prod       Flutter → live Firebase (Android)" -ForegroundColor Cyan
Write-Host "  ▸  .\dev.ps1 --prod --web Flutter → live Firebase (Chrome)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Emulator UI  →  http://127.0.0.1:4000" -ForegroundColor DarkGray
Write-Host "  Auth :9099   Firestore :8080   Functions :5001   Storage :9199" -ForegroundColor DarkGray
Write-Host ""
