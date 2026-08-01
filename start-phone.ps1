<#
.SYNOPSIS
    Runs Lending Nelson on a physical Android phone for trusted local Wi-Fi testing only.
.EXAMPLE
    .\start-phone.ps1 -PhoneAddress 192.168.254.112:40423 -ServerIp 192.168.254.110
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}:\d{1,5}$')]
    [string]$PhoneAddress,

    [Parameter(Mandatory = $true)]
    [ValidateScript({ $parsedAddress = $null; [ipaddress]::TryParse($_, [ref]$parsedAddress) })]
    [string]$ServerIp,

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
$LocalProperties = Join-Path $ProjectRoot "android\local.properties"
$SdkRoots = @()
if (Test-Path -LiteralPath $LocalProperties -PathType Leaf) {
    $sdkLine = Get-Content -LiteralPath $LocalProperties | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
    if ($sdkLine) {
        $SdkRoots += (($sdkLine -replace '^sdk\.dir=', '') -replace '\\\\', '\')
    }
}
$SdkRoots += @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, (Join-Path $env:LOCALAPPDATA "Android\Sdk")) | Where-Object { $_ }
$AdbExe = $null
foreach ($sdkRoot in $SdkRoots) {
    $candidate = Join-Path $sdkRoot "platform-tools\adb.exe"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $AdbExe = $candidate
        break
    }
}
if (-not $AdbExe) {
    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbCommand) { $AdbExe = $adbCommand.Source }
}
if (-not $AdbExe) {
    throw "adb was not found. Install Android platform-tools or set sdk.dir in android/local.properties."
}
$ApiUrl = "http://${ServerIp}:${Port}"

Write-Host "[DEV ONLY] Trusted local Wi-Fi launcher" -ForegroundColor Yellow
Write-Host "Phone: $PhoneAddress"
Write-Host "Backend: $ApiUrl"

& $AdbExe connect $PhoneAddress
if ($LASTEXITCODE -ne 0) {
    throw "ADB could not connect to $PhoneAddress"
}
Write-Host "[STOP] Closing the previous Lending Nelson app instance on the phone..." -ForegroundColor Yellow
& $AdbExe -s $PhoneAddress shell am force-stop com.nelson.lending
if ($LASTEXITCODE -ne 0) {
    throw "ADB could not stop the previous Lending Nelson app instance on $PhoneAddress"
}

function Test-BackendHealth {
    param (
        [Parameter(Mandatory = $true)]
        [string]$HealthUrl
    )
    try {
        $response = Invoke-RestMethod -Uri "${HealthUrl}/health" -TimeoutSec 2
        return $response.status -eq "ok"
    } catch {
        return $false
    }
}

function Stop-OwnedBackendOnPort {
    param ([int]$PortNumber)

    $connections = Get-NetTCPConnection -State Listen -LocalPort $PortNumber -ErrorAction SilentlyContinue
    foreach ($processId in @($connections | Select-Object -ExpandProperty OwningProcess -Unique)) {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
        $backendPath = [regex]::Escape($BackendDir)
        $isOwnedBackend = $process -and
            $process.CommandLine -match "(?i)uvicorn" -and
            ($process.CommandLine -match $backendPath -or $process.ExecutablePath -match $backendPath)
        if (-not $isOwnedBackend) {
            throw "Port $PortNumber is already owned by another process (PID $processId). Stop it manually or use -Port with a free port."
        }
        Write-Host "[STOP] Restarting Lending Nelson backend PID $processId for phone access..." -ForegroundColor Yellow
        $parent = Get-CimInstance Win32_Process -Filter "ProcessId = $($process.ParentProcessId)" -ErrorAction SilentlyContinue
        $isLauncherShell = $parent -and
            $parent.Name -match '^(powershell|pwsh)(\.exe)?$' -and
            $parent.CommandLine -match "(?i)uvicorn" -and
            $parent.CommandLine -match $backendPath
        Stop-ProcessTree -RootProcessId $(if ($isLauncherShell) { $parent.ProcessId } else { $processId })
    }
}

function Stop-ProcessTree {
    param (
        [Parameter(Mandatory = $true)]
        [int]$RootProcessId
    )

    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $RootProcessId" -ErrorAction SilentlyContinue
    foreach ($child in @($children)) {
        Stop-ProcessTree -RootProcessId $child.ProcessId
    }

    Stop-Process -Id $RootProcessId -Force -ErrorAction SilentlyContinue
}

function Stop-PreviousFlutterRun {
    $escapedApiUrl = [regex]::Escape("API_BASE_URL=$ApiUrl")
    $flutterProcesses = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessId -ne $PID -and
            $_.Name -match '^(dart|flutter|cmd)(\.exe)?$' -and
            $_.CommandLine -match '(?i)flutter_tools(\.snapshot)?' -and
            $_.CommandLine -match $escapedApiUrl
        }

    foreach ($process in @($flutterProcesses)) {
        Write-Host "[STOP] Previous Lending Nelson Flutter run PID $($process.ProcessId)..." -ForegroundColor Yellow
        Stop-ProcessTree -RootProcessId $process.ProcessId
    }
}

Write-Host "[CLEAN] Stopping previous Lending Nelson development processes..." -ForegroundColor Yellow
Stop-PreviousFlutterRun
Stop-OwnedBackendOnPort -PortNumber $Port

if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
    throw "Backend virtual-environment Python was not found at $VenvPython"
}

$backendArguments = @("-NoProfile", "-Command", "Set-Location '$BackendDir'; & '$VenvPython' -m uvicorn app.main:app --host 0.0.0.0 --port $Port")
$backendProcess = Start-Process powershell -ArgumentList $backendArguments -WindowStyle Hidden -PassThru

$healthy = $false
for ($attempt = 1; $attempt -le 15; $attempt++) {
    Start-Sleep -Milliseconds 800
    if (Test-BackendHealth -HealthUrl "http://127.0.0.1:${Port}") {
        $healthy = $true
        break
    }
}
if (-not $healthy) {
    if ($backendProcess -and -not $backendProcess.HasExited) {
        Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
    }
    throw "Backend health check failed; Flutter was not started."
}
if (-not (Test-BackendHealth -HealthUrl $ApiUrl)) {
    throw "Backend is healthy locally but $ApiUrl is unreachable. Allow inbound TCP port $Port through Windows Defender Firewall for the trusted Private network, then retry."
}
Write-Host "[OK] Backend restarted and is reachable from the LAN address." -ForegroundColor Green

$BorrowerDir = Join-Path $ProjectRoot "apps\borrower_mobile"

if ($App -eq "borrower") {
    Set-Location -LiteralPath $BorrowerDir
    Write-Host "[START] Launching Borrower App on $PhoneAddress..." -ForegroundColor Cyan
    flutter run -d $PhoneAddress --dart-define="API_BASE_URL=$ApiUrl"
} elseif ($App -eq "all") {
    Write-Host "[START] Launching Borrower App on $PhoneAddress in background..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList @("-NoExit", "-Command", "Set-Location '$BorrowerDir'; flutter run -d $PhoneAddress --dart-define=API_BASE_URL=$ApiUrl")
    Set-Location -LiteralPath $ProjectRoot
    Write-Host "[START] Launching Officer App on $PhoneAddress..." -ForegroundColor Cyan
    flutter run -d $PhoneAddress --dart-define="API_BASE_URL=$ApiUrl"
} else {
    Set-Location -LiteralPath $ProjectRoot
    Write-Host "[START] Launching Officer App on $PhoneAddress..." -ForegroundColor Cyan
    flutter run -d $PhoneAddress --dart-define="API_BASE_URL=$ApiUrl"
}

if ($LASTEXITCODE -ne 0) {
    throw "Flutter failed to build or launch on $PhoneAddress (exit code $LASTEXITCODE)."
}
