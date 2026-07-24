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

function Stop-OwnedPortProcess {
    param ([int]$PortNumber)

    $connections = Get-NetTCPConnection -State Listen -LocalPort $PortNumber -ErrorAction SilentlyContinue
    foreach ($processId in @($connections | Select-Object -ExpandProperty OwningProcess -Unique)) {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
        $isOwnedBackend = $process -and $process.CommandLine -match [regex]::Escape($ProjectRoot) -and $process.CommandLine -match "(?i)uvicorn"
        if (-not $isOwnedBackend) {
            throw "Port $PortNumber is already owned by another process (PID $processId). Stop it manually or select another port."
        }
        Write-Host "[STOP] Stopping existing Lending Nelson backend PID $processId..." -ForegroundColor Yellow
        Stop-Process -Id $processId -Force
    }
}

if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
    throw "Backend virtual-environment Python was not found at $VenvPython"
}

Write-Host "[INIT] Lending Nelson local development launcher" -ForegroundColor Cyan
Write-Host "API URL: $ApiUrl" -ForegroundColor Yellow

$backendProcess = $null
if ($LocalBackendRequired) {
    Stop-OwnedPortProcess -PortNumber $Port
    $backendArguments = @("-NoExit", "-Command", "Set-Location '$BackendDir'; & '$VenvPython' -m uvicorn app.main:app --host $BindHost --port $Port")
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
flutter run --dart-define="API_BASE_URL=$ApiUrl"