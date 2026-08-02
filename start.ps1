<#
.SYNOPSIS
    Starts the Lending Nelson backend and Flutter client for local development only.
.DESCRIPTION
    Uses HTTP only for trusted local testing. This script is not a production server launcher.
.EXAMPLE
    .\start.ps1 -Target android
.EXAMPLE
    .\start.ps1 -Target 192.168.254.110
.EXAMPLE
    .\start.ps1 -Target https://api.example.com
#>
[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Target = "android",

    [Parameter()]
    [ValidateSet("officer", "borrower", "all")]
    [string]$App = "officer",

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$BackendDir = Join-Path $ProjectRoot "backend"
$VenvPython = Join-Path $BackendDir ".venv\Scripts\python.exe"

$ApiUrl = switch -Regex ($Target) {
    "(?i)^android$" { "http://10.0.2.2:$Port"; break }
    "(?i)^ios$" { "http://localhost:$Port"; break }
    "(?i)^localhost$" { "http://localhost:$Port"; break }
    "(?i)^https?://" { $Target.TrimEnd("/"); break }
    default { "http://${Target}:$Port" }
}

$LocalBackendRequired = $ApiUrl -match "^http://(localhost|127\.0\.0\.1|10\.0\.2\.2|\[?::1\]?)(:|/)" -or ($ApiUrl -eq "http://${Target}:$Port")
$BindHost = if ($Target -match "(?i)^(android|ios|localhost)$") { "127.0.0.1" } else { "0.0.0.0" }

function Stop-ExistingProjectProcesses {
    param (
        [int]$PortNumber,
        [string]$Path
    )

    # 1. Stop processes listening on the backend port
    $connections = Get-NetTCPConnection -State Listen -LocalPort $PortNumber -ErrorAction SilentlyContinue
    foreach ($processId in @($connections | Select-Object -ExpandProperty OwningProcess -Unique)) {
        if ($processId -and $processId -ne $PID) {
            Write-Host "[STOP] Stopping process listening on port $PortNumber (PID $processId)..." -ForegroundColor Yellow
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        }
    }

    # 2. Stop existing backend uvicorn processes for this project
    $uvicornProcesses = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -match [regex]::Escape($Path) -and $_.CommandLine -match "(?i)uvicorn"
    }
    foreach ($proc in $uvicornProcesses) {
        Write-Host "[STOP] Stopping existing backend process (PID $($proc.ProcessId))..." -ForegroundColor Yellow
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    }

    # 3. Stop existing Flutter / Dart client processes for this project
    $flutterProcesses = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -match [regex]::Escape($Path) -and $_.CommandLine -match "(?i)\b(flutter|dart)\b"
    }
    foreach ($proc in $flutterProcesses) {
        Write-Host "[STOP] Stopping existing Flutter client process (PID $($proc.ProcessId))..." -ForegroundColor Yellow
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
    throw "Backend virtual-environment Python was not found at $VenvPython"
}

Write-Host "[INIT] Lending Nelson local development launcher" -ForegroundColor Cyan
Write-Host "API URL: $ApiUrl" -ForegroundColor Yellow

# Clean up any previously running backend or Flutter client instances
Stop-ExistingProjectProcesses -PortNumber $Port -Path $ProjectRoot

$backendProcess = $null
if ($LocalBackendRequired) {
    Write-Host "[START] Launching backend server..." -ForegroundColor Cyan
    $backendArguments = @("-NoExit", "-Command", "`$env:APP_ENV='development'; `$env:LOCAL_BORROWER_OTP_ENABLED='true'; Set-Location '$BackendDir'; & '$VenvPython' -m uvicorn app.main:app --host $BindHost --port $Port")
    $backendProcess = Start-Process powershell -ArgumentList $backendArguments -PassThru

    $healthy = $false
    for ($attempt = 1; $attempt -le 15; $attempt++) {
        Start-Sleep -Milliseconds 800
        try {
            $response = Invoke-RestMethod -Uri "http://127.0.0.1:${Port}/health" -TimeoutSec 2
            if ($response.status -eq "ok") {
                $healthy = $true
                break
            }
        } catch {
            Write-Host "." -NoNewline -ForegroundColor Gray
        }
    }
    Write-Host ""

    if (-not $healthy) {
        if ($backendProcess -and -not $backendProcess.HasExited) {
            Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
        }
        throw "Backend health check failed; Flutter was not started."
    }
    Write-Host "[OK] Backend health check passed." -ForegroundColor Green
}

Set-Location -LiteralPath $ProjectRoot
$flutterCommand = Get-Command flutter -ErrorAction Stop
$flutterBin = Split-Path -Parent $flutterCommand.Source
$flutterSdkRoot = Split-Path -Parent $flutterBin

# Flutter invokes Git during tool startup. In managed/sandboxed development
# sessions the SDK may be owned by the desktop account, so scope Git's
# safe-directory exception to this child process instead of changing global
# user configuration.
$env:GIT_CONFIG_COUNT = "1"
$env:GIT_CONFIG_KEY_0 = "safe.directory"
$env:GIT_CONFIG_VALUE_0 = $flutterSdkRoot

$BorrowerDir = Join-Path $ProjectRoot "apps\borrower_mobile"

$flutterArguments = @(
    "run",
    "--dart-define=API_BASE_URL=$ApiUrl",
    "--dart-define=APP_ENV=development",
    "--dart-define=LOCAL_BORROWER_OTP_ENABLED=true"
)

if ($App -eq "borrower") {
    Set-Location -LiteralPath $BorrowerDir
    Write-Host "[START] Borrower Flutter client ($($flutterArguments -join ' '))" -ForegroundColor Cyan
    & flutter @flutterArguments
} elseif ($App -eq "all") {
    Write-Host "[START] Launching Borrower App in background..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList @("-NoExit", "-Command", "Set-Location '$BorrowerDir'; flutter run --dart-define=API_BASE_URL=$ApiUrl --dart-define=APP_ENV=development --dart-define=LOCAL_BORROWER_OTP_ENABLED=true")
    Set-Location -LiteralPath $ProjectRoot
    Write-Host "[START] Officer Flutter client ($($flutterArguments -join ' '))" -ForegroundColor Cyan
    & flutter @flutterArguments
} else {
    Set-Location -LiteralPath $ProjectRoot
    Write-Host "[START] Officer Flutter client ($($flutterArguments -join ' '))" -ForegroundColor Cyan
    & flutter @flutterArguments
}

if ($LASTEXITCODE -ne 0) {
    throw "Flutter exited with code $LASTEXITCODE."
}
