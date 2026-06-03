#Requires -Version 5.1
# Frontline -- project setup (Windows PowerShell)
# Run with: .\setup.ps1

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $Root

function ok($msg)   { Write-Host "  [+]  $msg" -ForegroundColor Green }
function fail($msg) { Write-Host "  [x]  $msg" -ForegroundColor Red; exit 1 }
function step($msg) { Write-Host "`n  >>  $msg" -ForegroundColor Cyan }
function info($msg) { Write-Host "       $msg" -ForegroundColor DarkGray }
function warn($msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function hr()       { Write-Host ("  " + ("-" * 57)) -ForegroundColor DarkGray }

Write-Host ""
Write-Host "  Frontline  -  project setup" -ForegroundColor Magenta
hr
Write-Host ""

# -- Prerequisites -------------------------------------------------------------
step "Checking prerequisites"

function Require-Command($cmd, $label, $hint) {
  if (Get-Command $cmd -ErrorAction SilentlyContinue) {
    $ver = (& $cmd --version 2>&1 | Select-Object -First 1)
    ok "$label  $ver"
  } else {
    fail "$label not found$hint"
  }
}

Require-Command flutter flutter " -- https://docs.flutter.dev/get-started/install"

$dartVer = (dart --version 2>&1 | Select-Object -First 1) -replace '.*?(\d+\.\d+\.\d+).*','$1'
$dartParts = $dartVer.Split('.')
if ([int]$dartParts[0] -lt 3 -or ([int]$dartParts[0] -eq 3 -and [int]$dartParts[1] -lt 9)) {
  fail "Dart $dartVer is too old -- sdk: ^3.9.0 required (run: flutter upgrade)"
}

Require-Command node node " -- Install Node.js 24+ from https://nodejs.org"
$nodeMajor = (node --version) -replace 'v(\d+).*','$1'
if ([int]$nodeMajor -lt 24) {
  warn "Node $nodeMajor detected -- project targets Node 24"
  info "Upgrade: https://nodejs.org"
}

Require-Command npm npm

if (Get-Command java -ErrorAction SilentlyContinue) {
  $javaVer = java -version 2>&1 | Select-Object -First 1
  ok "java  $javaVer"
} else {
  warn "java not found -- needed for Android builds and Firebase emulators"
  info "Install JDK 21+ from https://adoptium.net"
}

if (Get-Command firebase -ErrorAction SilentlyContinue) {
  $fbVer = firebase --version 2>&1 | Select-Object -First 1
  ok "firebase  $fbVer"
} else {
  warn "firebase-tools not installed globally"
  info "Run: npm install -g firebase-tools"
}

if (Get-Command flutterfire -ErrorAction SilentlyContinue) {
  ok "flutterfire"
} else {
  warn "flutterfire CLI not installed"
  info "Run: dart pub global activate flutterfire_cli"
}

# -- Flutter dependencies ------------------------------------------------------
step "Flutter dependencies"
info "flutter pub get -> apps/mobile"
Push-Location apps/mobile
& flutter pub get
Pop-Location
ok "Flutter packages ready"

# -- Code generation -----------------------------------------------------------
step "Code generation (Freezed + Riverpod)"
info "build_runner build -> apps/mobile"
Push-Location apps/mobile
& dart run build_runner build --delete-conflicting-outputs
Pop-Location
ok "Generated code up to date"

# -- Cloud Functions -----------------------------------------------------------
step "Cloud Functions dependencies"
info "npm install -> functions/"
Push-Location functions
& npm install --silent
Pop-Location
ok "Node packages ready"

# -- .env ----------------------------------------------------------------------
step ".env"
$envFile    = Join-Path $Root "apps\mobile\.env"
$envExample = Join-Path $Root "apps\mobile\.env.example"

if (-not (Test-Path $envFile)) {
  Copy-Item $envExample $envFile
  ok "Created apps/mobile/.env"
} else {
  ok "apps/mobile/.env already exists"
}

# Parse .env
$envVars = @{}
Get-Content $envFile | ForEach-Object {
  if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.*)\s*$') {
    $envVars[$Matches[1]] = $Matches[2].Trim()
  }
}

if ([string]::IsNullOrEmpty($envVars['MAPBOX_ACCESS_TOKEN'])) {
  warn "MAPBOX_ACCESS_TOKEN is not set."
  info "Get a token at https://account.mapbox.com/access-tokens/"
  $token = Read-Host "  Enter your Mapbox public access token (or press Enter to skip)"
  if (-not [string]::IsNullOrEmpty($token)) {
    $content = Get-Content $envFile
    $content = $content -replace '^MAPBOX_ACCESS_TOKEN=.*', "MAPBOX_ACCESS_TOKEN=$token"
    if ($content -notmatch 'MAPBOX_ACCESS_TOKEN=') {
      $content += "`nMAPBOX_ACCESS_TOKEN=$token"
    }
    $content | Set-Content $envFile
    ok "MAPBOX_ACCESS_TOKEN saved to apps/mobile/.env"
  } else {
    warn "Skipped -- map rendering will not work until token is set"
  }
} else {
  ok "MAPBOX_ACCESS_TOKEN set"
}

# -- Firebase setup ------------------------------------------------------------
step "Firebase configuration"
$firebaseOptions = Join-Path $Root "apps\mobile\lib\firebase_options.dart"

if (Select-String -Path $firebaseOptions -Pattern 'TODO' -Quiet) {
  warn "firebase_options.dart not configured."
  info "Create a Firebase project at https://console.firebase.google.com"
  $projectId = Read-Host "  Enter your Firebase project ID (or press Enter to skip)"
  if (-not [string]::IsNullOrEmpty($projectId)) {
    if (Get-Command flutterfire -ErrorAction SilentlyContinue) {
      info "Running flutterfire configure..."
      Push-Location apps/mobile
      & flutterfire configure --project=$projectId --platforms=android,web --yes
      Pop-Location
      ok "Firebase configured"
    } else {
      warn "flutterfire CLI not found -- configure manually:"
      info "dart pub global activate flutterfire_cli"
      info "cd apps/mobile; flutterfire configure --project=$projectId --platforms=android,web"
      (Get-Content "$Root\.firebaserc") -replace 'TODO-your-project-id', $projectId |
        Set-Content "$Root\.firebaserc"
      ok "Updated .firebaserc with project ID"
    }
  } else {
    warn "Skipped -- emulators will still work with USE_EMULATOR=true"
  }
} else {
  ok "firebase_options.dart already configured"
}

# -- Git hooks -----------------------------------------------------------------
step "Git hooks"
& git config core.hooksPath .githooks
ok "pre-commit hook active  (dart format + prettier auto-fix; flutter analyze + eslint gate)"
ok "pre-push hook active    (flutter test + pubspec.lock check + functions lint + tsc)"

# -- Done ----------------------------------------------------------------------
Write-Host ""
hr
Write-Host ""
Write-Host "  Setup complete." -ForegroundColor Green
Write-Host ""
Write-Host "  What to do next" -ForegroundColor White
Write-Host ""
Write-Host "  >>  .\dev.ps1              Emulators + Flutter on Android" -ForegroundColor Cyan
Write-Host "  >>  .\dev.ps1 --web        Emulators + Flutter on Chrome" -ForegroundColor Cyan
Write-Host "  >>  .\dev.ps1 --prod       Flutter -> live Firebase (Android)" -ForegroundColor Cyan
Write-Host "  >>  .\dev.ps1 --prod --web Flutter -> live Firebase (Chrome)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Emulator UI  ->  http://127.0.0.1:4000" -ForegroundColor DarkGray
Write-Host "  Auth :9099   Firestore :8080   Functions :5001   Storage :9199" -ForegroundColor DarkGray
Write-Host ""
