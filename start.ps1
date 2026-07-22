<#
.SYNOPSIS
    Professional Local Development Environment Launcher for Lending Nelson.
.DESCRIPTION
    Launches the FastAPI backend and Flutter mobile client with automatic process cleanup,
    health checks, and target platform configuration.
.EXAMPLE
    .\start.ps1 -Target android
.EXAMPLE
    .\start.ps1 -Target ios
.EXAMPLE
    .\start.ps1 -Target 192.168.1.50
#>
[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Target = "android",

    [Parameter()]
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

# Base Directory Resolution
$ProjectRoot = $PSScriptRoot
$BackendDir  = Join-Path $ProjectRoot "backend"
$VenvPython  = Join-Path $BackendDir ".venv\Scripts\python.exe"

# Resolve API URL based on Target
$ApiUrl = switch -Regex ($Target) {
    "(?i)^android$"   { "http://10.0.2.2:$Port" }
    "(?i)^ios$"       { "http://localhost:$Port" }
    "(?i)^localhost$" { "http://localhost:$Port" }
    default           {
        if ($Target -match "^http://") { $Target } else { "http://${Target}:$Port" }
    }
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  [INIT] Launching Lending Nelson Dev Environment" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Target API URL : $ApiUrl" -ForegroundColor Yellow
Write-Host " Backend Port   : $Port" -ForegroundColor Yellow
Write-Host " Project Root   : $ProjectRoot" -ForegroundColor Gray
Write-Host ""

# ------------------------------------------------------------------
# Helper Function: Stop process using specified port
# ------------------------------------------------------------------
function Stop-PortProcess {
    param ([int]$PortNumber)
    $connections = Get-NetTCPConnection -LocalPort $PortNumber -ErrorAction SilentlyContinue
    if ($connections) {
        $pidsToKill = $connections | Select-Object -ExpandProperty OwningProcess -Unique
        foreach ($procId in $pidsToKill) {
            try {
                $procName = (Get-Process -Id $procId -ErrorAction SilentlyContinue).ProcessName
                Write-Host "[STOP] Terminating existing process on port ${PortNumber} (PID: ${procId} - ${procName})..." -ForegroundColor Yellow
                Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            } catch {
                # Ignore cleanup errors
            }
        }
        Start-Sleep -Seconds 1
    }
}

# ------------------------------------------------------------------
# 1. Clean up stale processes on port
# ------------------------------------------------------------------
Stop-PortProcess -PortNumber $Port

# ------------------------------------------------------------------
# 2. Validate Environment Setup
# ------------------------------------------------------------------
if (-not (Test-Path $VenvPython)) {
    Write-Error "Virtual environment Python executable not found at: $VenvPython`nPlease initialize .venv in the backend directory first."
    exit 1
}

# ------------------------------------------------------------------
# 3. Launch Backend Service
# ------------------------------------------------------------------
Write-Host "[BACKEND] Launching FastAPI Backend Server..." -ForegroundColor Green
$backendCmd = "Set-Location '$BackendDir'; & '$VenvPython' -m uvicorn app.main:app --reload --host 0.0.0.0 --port $Port"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd

# ------------------------------------------------------------------
# 4. Backend Health Check Verification
# ------------------------------------------------------------------
Write-Host "[CHECK] Waiting for Backend Health Check..." -NoNewline -ForegroundColor Gray
$maxRetries = 10
$healthy = $false
for ($i = 1; $i -le $maxRetries; $i++) {
    Start-Sleep -Milliseconds 800
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:${Port}/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.status -eq "ok" -or $response) {
            $healthy = $true
            break
        }
    } catch {
        Write-Host "." -NoNewline -ForegroundColor Gray
    }
}

Write-Host ""
if ($healthy) {
    Write-Host "[OK] Backend is UP and Healthy!" -ForegroundColor Green
} else {
    Write-Host "[WARN] Backend health check timed out, continuing..." -ForegroundColor Yellow
}

# ------------------------------------------------------------------
# 5. Launch Frontend (Flutter)
# ------------------------------------------------------------------
Write-Host ""
Write-Host "[FRONTEND] Starting Flutter App targeting [$Target]..." -ForegroundColor Cyan
Set-Location -Path $ProjectRoot
flutter run --dart-define=API_BASE_URL=$ApiUrl
