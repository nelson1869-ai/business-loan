# Android Phone Setup

This guide installs and updates Lending Nelson on a physical Android phone
while FastAPI and PostgreSQL run on the development PC.

## Architecture

```text
Android phone
    |
    | Trusted Wi-Fi (FastAPI port 8000)
    v
Development PC
    |
    +-- Flutter source
    +-- FastAPI
    +-- PostgreSQL
```

The phone must never connect directly to PostgreSQL. FastAPI is the only
service that should access the database.

## Requirements

- The phone and PC are connected to the same trusted network.
- Android Developer options are enabled.
- USB debugging and Wireless debugging are enabled.
- Flutter recognizes the project.
- PostgreSQL is running on the PC.
- FastAPI is running and listening on `0.0.0.0:8000`.

## 1. Find the PC address

From PowerShell:

```powershell
Get-NetIPConfiguration |
  Where-Object {$_.IPv4DefaultGateway -ne $null} |
  Select-Object InterfaceAlias,IPv4Address
```

Example:

```text
IPv4Address : 192.168.254.110
```

The address can change after reconnecting the PC or restarting the router.
Check it again when the phone cannot reach the API.

## 2. Start FastAPI

Open a dedicated PowerShell window:

```powershell
Set-Location D:\Development\lending_nelson\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app `
  --host 0.0.0.0 `
  --port 8000
```

Keep this window open while using the phone.

Verify the API locally:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Verify it through the LAN address:

```powershell
Invoke-RestMethod http://192.168.254.110:8000/health
```

Both checks should return:

```json
{"status":"ok"}
```

## 3. Install initially through USB

Connect the unlocked phone by USB and accept the debugging authorization.

Check the device:

```powershell
Set-Location D:\Development\lending_nelson
flutter devices
```

Install the application, replacing the device ID and PC address when needed:

```powershell
flutter run -d ANDROID_DEVICE_ID `
  --dart-define=API_BASE_URL=http://192.168.254.110:8000
```

After installation, USB is not required for normal application use. The PC,
FastAPI, and Wi-Fi connection are still required for live server operations.

## 4. Pair Android for wireless debugging

On the phone:

1. Open **Settings > Developer options > Wireless debugging**.
2. Tap **Pair device with pairing code**.
3. Keep the pairing screen open.
4. Note the temporary pairing address and six-digit code.

ADB is installed at:

```text
D:\Development\Android\platform-tools\adb.exe
```

Pair immediately, using the temporary pairing port shown by Android:

```powershell
& "D:\Development\Android\platform-tools\adb.exe" pair PHONE_IP:PAIRING_PORT
```

Enter the temporary code only when ADB prompts for it. Do not save pairing
codes in source files or documentation.

Expected result:

```text
Successfully paired
```

If ADB reports a protocol fault, close the pairing dialog, generate a new
pairing code and port, and retry immediately.

## 5. Connect wirelessly

Return to the main **Wireless debugging** screen. Use its **IP address & port**,
which is normally different from the temporary pairing port:

```powershell
& "D:\Development\Android\platform-tools\adb.exe" connect PHONE_IP:CONNECTION_PORT
```

Confirm Flutter detects the wireless phone:

```powershell
flutter devices
```

The phone should appear under `wirelessly connected device`.

## 6. Install updates through Wi-Fi

Copy the complete wireless device ID reported by `flutter devices`:

```powershell
flutter run -d "WIRELESS_DEVICE_ID" `
  --dart-define=API_BASE_URL=http://192.168.254.110:8000
```

Keep the phone unlocked during the build and installation.

## Normal use

Once installed, the app can be opened from the Android app drawer without
Flutter or USB. For live operations:

- The PC must be powered on.
- PostgreSQL and FastAPI must be running.
- The phone and PC must be on the same trusted network.
- Windows Firewall must permit FastAPI port `8000` on the trusted network.
- PostgreSQL port `5434` must not be exposed to the phone or internet.

The phone may display cached data while offline, but PostgreSQL remains the
authoritative financial record.

## Troubleshooting

### Port 8000 is already in use

Check whether FastAPI is already running:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Do not start a second server when the existing endpoint returns `status: ok`.

### `adb` is not recognized

Use its absolute path:

```powershell
& "D:\Development\Android\platform-tools\adb.exe" version
```

### Phone disappears from `flutter devices`

1. Confirm the phone and PC are on the same Wi-Fi.
2. Confirm Wireless debugging remains enabled.
3. Reconnect using the current connection address and port.
4. Pair again if Android has forgotten the PC.

### ADB protocol fault or pairing failure

If `adb pair` returns `error: protocol fault (couldn't read status message)`:

1. **Reset ADB Daemon:**

   ```powershell
   & "D:\Development\Android\platform-tools\adb.exe" kill-server
   & "D:\Development\Android\platform-tools\adb.exe" start-server
   ```

2. **Try Direct Connection (If already paired):**
   Use the main **IP address & port** on the Wireless debugging screen (not the pairing popup):

   ```powershell
   & "D:\Development\Android\platform-tools\adb.exe" connect 192.168.254.112:40423

   flutter run -d "192.168.254.112:40423" --dart-define=API_BASE_URL=http://192.168.254.110:8000

   .\start-phone.ps1 -PhoneAddress 192.168.254.112:40423 -ServerIp 192.168.254.110
   ```

3. **USB One-Time Authorization Fallback:**
   If wireless pairing fails repeatedly, plug the phone into the PC via USB once, tap **"Always allow from this computer"**, unplug the USB cable, and proceed directly with `adb connect PHONE_IP:CONNECTION_PORT`.

### App cannot reach FastAPI

1. Check the PC IPv4 address again.
2. Test `/health` through the LAN address.
3. Confirm the build used the current `API_BASE_URL`.
4. Confirm FastAPI uses `--host 0.0.0.0`.
5. Check Windows Firewall access for port `8000`.

