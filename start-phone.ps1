<#
.SYNOPSIS
    Automated Phone Launcher for Lending Nelson.
.DESCRIPTION
    Connects to physical Android phone via ADB wireless debugging, verifies the backend health,
    and runs the Flutter app targeting the phone.
.EXAMPLE
    .\start-phone.ps1
.EXAMPLE
    .\start-phone.ps1 -PhoneAddress 192.168.254.112:40423 -ServerIp 192.168.254.110
#>
[CmdletBinding()]
param (
    [Parameter()]
    [string]$PhoneAddress = "192.168.254.112:40423",

    [Parameter()]
    [string]$ServerIp = "192.168.254.110",

    [Parameter()]
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$ProjectRoot = $PSScriptRoot
$BackendDir  = Join-Path $ProjectRoot "backend"
$VenvPython  = Join-Path $BackendDir ".venv\Scripts\python.exe"
$AdbExe      = "D:\Development\Android\platform-tools\adb.exe"

if (-not (Test-Path $AdbExe)) {
    $AdbExe = "adb"
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  [INIT] Wireless Phone Launcher - Lending Nelson" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Target Phone  : $PhoneAddress" -ForegroundColor Yellow
Write-Host " Server Base   : http://${ServerIp}:${Port}" -ForegroundColor Yellow
Write-Host ""

# 1. Connect ADB Wireless
Write-Host "[ADB] Connecting to wireless device at $PhoneAddress..." -ForegroundColor Green
& $AdbExe connect $PhoneAddress

# 2. Check Backend Health
$ApiUrl = "http://${ServerIp}:${Port}"
Write-Host "[CHECK] Checking Backend server at $ApiUrl..." -NoNewline -ForegroundColor Gray
$healthy = $false
try {
    $response = Invoke-RestMethod -Uri "${ApiUrl}/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($response.status -eq "ok" -or $response) {
        $healthy = $true
    }
} catch {
    # Backend not responding
}

if ($healthy) {
    Write-Host " UP!" -ForegroundColor Green
} else {
    Write-Host " DOWN! (Launching FastAPI backend process...)" -ForegroundColor Yellow
    if (Test-Path $VenvPython) {
        $backendCmd = "Set-Location '$BackendDir'; & '$VenvPython' -m uvicorn app.main:app --host 0.0.0.0 --port $Port"
        Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd
        Start-Sleep -Seconds 2
    } else {
        Write-Host "[WARN] Backend Python venv not found at $VenvPython. Proceeding with app launch..." -ForegroundColor Yellow
    }
}

# 3. Launch Flutter on Phone
Write-Host ""
Write-Host "[FLUTTER] Launching app on phone [$PhoneAddress]..." -ForegroundColor Cyan
Set-Location -Path $ProjectRoot
flutter run -d $PhoneAddress --dart-define=API_BASE_URL=$ApiUrl
