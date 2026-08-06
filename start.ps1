<#
.SYNOPSIS
    Starts the backend, officer app, and borrower app for local development.
.DESCRIPTION
    With no arguments, starts the local backend and both Android applications
    against the Android emulator API address. Uses HTTP only for trusted local
    testing. This script is not a production server launcher.
.EXAMPLE
    .\start.ps1
    Starts the backend and both Flutter applications on the default emulator.
.EXAMPLE
    .\start.ps1 -Target android -App borrower
    Starts only the borrower application and the local backend.
.EXAMPLE
    .\start.ps1 -Target 192.168.254.110 -App all
    Starts both applications using the computer's LAN API address.
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
    [string]$App = "all",

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$Port = 8000,

    [Parameter()]
    [string]$Device
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$BackendDir = Join-Path $ProjectRoot "backend"
$VenvPython = Join-Path $BackendDir ".venv\Scripts\python.exe"

$ApiUrl = switch -Regex ($Target) {
    "(?i)^android$" { "http://10.0.2.2:$Port"; break }
    "(?i)^ios$" { "http://localhost:$Port"; break }
    "(?i)^localhost$" { "http://localhost:$Port"; break }
    "(?i)^render$" { "https://lending-nelson-api.onrender.com"; break }
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
Write-Host "Applications: $App" -ForegroundColor Yellow

# Clean up any previously running backend or Flutter client instances
Stop-ExistingProjectProcesses -PortNumber $Port -Path $ProjectRoot

$backendProcess = $null
if ($LocalBackendRequired) {
    Write-Host "[START] Launching backend server..." -ForegroundColor Cyan
    $backendArguments = @("-NoExit", "-Command", "`$env:APP_ENV='development'; Set-Location '$BackendDir'; & '$VenvPython' -m uvicorn app.main:app --host $BindHost --port $Port")
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

if (-not $Device) {
    if ($Target -match "(?i)^android$") {
        $devicesOutput = & flutter devices 2>&1
        $emulatorLine = $devicesOutput | Where-Object { $_ -match "emulator-\d+" } | Select-Object -First 1
        if ($emulatorLine -and $emulatorLine -match "(emulator-\d+)") {
            $Device = $matches[1]
        } else {
            Write-Host "[INIT] Launching Android emulator..." -ForegroundColor Cyan
            & flutter emulators --launch Small_Phone 2>&1 | Out-Null
            for ($i = 1; $i -le 10; $i++) {
                Start-Sleep -Seconds 2
                $devicesOutput = & flutter devices 2>&1
                $emulatorLine = $devicesOutput | Where-Object { $_ -match "emulator-\d+" } | Select-Object -First 1
                if ($emulatorLine -and $emulatorLine -match "(emulator-\d+)") {
                    $Device = $matches[1]
                    break
                }
            }
            if (-not $Device) {
                $Device = "emulator-5554"
            }
        }
    } elseif ($Target -match "(?i)^(ios|localhost)$") {
        $Device = "windows"
    }
}

$flutterArguments = @(
    "run",
    "--flavor=development",
    "--dart-define=API_BASE_URL=$ApiUrl",
    "--dart-define=APP_ENV=development"
)

if ($Device) {
    $flutterArguments += @("-d", $Device)
}

$deviceFlag = if ($Device) { "-d $Device " } else { "" }

if ($App -eq "borrower") {
    Set-Location -LiteralPath $BorrowerDir
    Write-Host "[START] Borrower Flutter client ($($flutterArguments -join ' '))" -ForegroundColor Cyan
    & flutter @flutterArguments
} elseif ($App -eq "all") {
    Write-Host "[START] Launching Borrower App in background..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList @("-NoExit", "-Command", "Set-Location '$BorrowerDir'; flutter run ${deviceFlag}--flavor=development --dart-define=API_BASE_URL=$ApiUrl --dart-define=APP_ENV=development")
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
