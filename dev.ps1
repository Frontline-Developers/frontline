# Frontline — dev runner (Windows PowerShell)
# Usage: .\dev.ps1 [--prod] [--web] [--emulator-only]

param(
  [switch]$prod,
  [switch]$web,
  [switch]$emulatorOnly,
  [switch]$help
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Write-Ok($msg)   { Write-Host "  ✓  $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  ✗  $msg" -ForegroundColor Red; exit 1 }
function Write-Info($msg) { Write-Host "     $msg" -ForegroundColor DarkGray }
function Write-Log($msg)  { Write-Host "  ▸  $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "  ⚠  $msg" -ForegroundColor Yellow }
function Write-Hr        { Write-Host ("─" * 60) -ForegroundColor DarkGray }

if ($help) {
  Write-Host ""
  Write-Host "Usage: .\dev.ps1 [--prod] [--web] [--emulator-only]"
  Write-Host ""
  Write-Host "  --prod           Connect to live Firebase instead of local emulators"
  Write-Host "  --web            Run on Chrome instead of Android"
  Write-Host "  --emulator-only  Start Firebase emulators only — no Flutter"
  Write-Host ""
  exit 0
}

if ($emulatorOnly -and $prod) {
  Write-Fail "--emulator-only and --prod are mutually exclusive"
}

# ── Header ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Frontline  ·  dev runner" -ForegroundColor Magenta
Write-Hr
Write-Host ""

$platform = if ($emulatorOnly) { "none (emulator-only)" } elseif ($web) { "Chrome" } else { "auto-detect" }
$backend  = if ($prod) { "Production Firebase" } else { "Local emulators" }

Write-Host "  Platform  $platform"
Write-Host "  Backend   $backend"
Write-Host ""

if ($prod) { Write-Warn "You are connecting to LIVE Firebase — real data, real users." }

# ── Load .env ─────────────────────────────────────────────────────────────────
$envFile    = Join-Path $Root "apps\mobile\.env"
$envExample = Join-Path $Root "apps\mobile\.env.example"

if (-not (Test-Path $envFile)) {
  if (Test-Path $envExample) {
    Copy-Item $envExample $envFile
    Write-Warn "apps/mobile/.env not found — created from .env.example"
    Write-Info "Set MAPBOX_ACCESS_TOKEN in apps/mobile/.env or run .\setup.ps1"
  }
}

$envVars = @{}
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([A-Z_]+)=(.*)$') {
      $envVars[$matches[1]] = $matches[2]
    }
  }
}

$mapboxToken = $envVars['MAPBOX_ACCESS_TOKEN']
if ([string]::IsNullOrEmpty($mapboxToken)) {
  Write-Warn "MAPBOX_ACCESS_TOKEN is not set — map rendering will not work."
  Write-Info "Run .\setup.ps1 to configure, or set it in apps/mobile/.env"
}

# ── Flutter args ──────────────────────────────────────────────────────────────
$flutterArgs = @()
if ($web)  { $flutterArgs += @("-d", "chrome") }
if ($prod) { $flutterArgs += "--dart-define=USE_EMULATOR=false" }
if (-not [string]::IsNullOrEmpty($mapboxToken)) {
  $flutterArgs += "--dart-define=MAPBOX_ACCESS_TOKEN=$mapboxToken"
}

# ── Emulator startup ──────────────────────────────────────────────────────────
function Test-Port($port) {
  try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $tcp.Connect("127.0.0.1", $port)
    $tcp.Close()
    return $true
  } catch { return $false }
}

function Test-EmulatorsUp {
  foreach ($port in @(9099, 8080, 5001, 9199)) {
    if (-not (Test-Port $port)) { return $false }
  }
  return $true
}

$emulatorJob = $null
$logFile = $null

if (-not $prod) {
  try {
    if (Test-EmulatorsUp) {
      Write-Ok "Emulators already running — attaching"
      Write-Info "Emulator UI → http://127.0.0.1:4000"
    } else {
      $null = New-Item -ItemType Directory -Path "$Root\logs" -Force
      $logFile = Join-Path "$Root\logs" "emulator-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

      # Build functions first
      Write-Log "Building Cloud Functions..."
      Push-Location functions
      & npm run build 2>&1 | Out-File $logFile
      Pop-Location
      Write-Ok "Functions built"

      Write-Log "Starting Firebase emulators..."
      Write-Info "Emulator UI → http://127.0.0.1:4000"
      $emulatorJob = Start-Job -ScriptBlock {
        param($root, $log)
        Set-Location $root
        & firebase emulators:start --only functions,auth,firestore,storage 2>&1 | Out-File $log -Append
      } -ArgumentList $Root, $logFile

      $maxWait = 90
      foreach ($item in @(
        @{Name="auth"; Port=9099},
        @{Name="firestore"; Port=8080},
        @{Name="functions"; Port=5001},
        @{Name="storage"; Port=9199}
      )) {
        $elapsed = 0
        Write-Host "  Waiting for $($item.Name) emulator on :$($item.Port)" -NoNewline
        while (-not (Test-Port $item.Port)) {
          Write-Host "." -NoNewline
          Start-Sleep 1
          $elapsed++
          if ($elapsed -ge $maxWait) {
            Write-Host ""
            Write-Fail "$($item.Name) emulator didn't respond after ${maxWait}s."
          }
        }
        Write-Host " ready" -ForegroundColor Green
      }
      Write-Ok "Emulator UI → http://127.0.0.1:4000"
    }
  } catch {
    Write-Fail "Emulator startup failed: $_"
  }
}

# ── Flutter ───────────────────────────────────────────────────────────────────
if ($emulatorOnly) {
  Write-Host ""
  Write-Ok "Emulators ready"
  Write-Info "Example: cd functions; npm test"
  Write-Hr
  Write-Host ""
  Write-Host "  Press Ctrl+C to stop." -ForegroundColor DarkGray
  if ($emulatorJob) {
    Wait-Job $emulatorJob | Out-Null
  } else {
    while ($true) { Start-Sleep 60 }
  }
} else {
  Write-Host ""
  $target = if ($web) { "on Chrome" } else { "" }
  Write-Log "Starting Flutter $target..."
  Write-Hr
  Write-Host ""

  Push-Location apps/mobile
  & flutter run @flutterArgs
  Pop-Location
}

if ($emulatorJob) {
  Stop-Job $emulatorJob -ErrorAction SilentlyContinue
  Remove-Job $emulatorJob -ErrorAction SilentlyContinue
}
