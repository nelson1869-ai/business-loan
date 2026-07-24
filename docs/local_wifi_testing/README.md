# Local Wi-Fi Android Testing

Use this workflow only for development testing when the Windows backend PC and Android phone are connected to the same trusted Wi-Fi network. It is not a production deployment and does not provide Internet access or HTTPS.

## 1. Find the backend PC address

```powershell
ipconfig
```

Use the IPv4 address of the active Wi-Fi or Ethernet adapter. The examples below use `192.168.254.110`; replace it if the address changes.

## 2. Start the backend on the LAN interface

From the repository root:

```powershell
Set-Location backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Keep this terminal open. Configure Windows Defender Firewall to allow TCP port 8000 only on the Private profile and trusted local network. Never expose PostgreSQL port 5432 to the network.

## 3. Verify backend health

In a second PowerShell terminal:

```powershell
Invoke-RestMethod "http://127.0.0.1:8000/health"
Invoke-RestMethod "http://192.168.254.110:8000/health"
```

Both commands should return a response with `status` equal to `ok`.

## 4. Run the Android app

Enable Android developer options and USB debugging, connect the phone, and confirm Flutter detects it:

```powershell
flutter devices
```

From the repository root, run:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.254.110:8000
```

The phone and backend PC must remain on the same Wi-Fi. If the PC IPv4 address changes, update `API_BASE_URL`.

Alternatively, use the validated phone launcher and supply the current wireless ADB address and backend PC address explicitly:

```powershell
.\start-phone.ps1 -PhoneAddress 192.168.254.112:40423 -ServerIp 192.168.254.110
```

Git Bash equivalent:

```bash
./start-phone.sh 192.168.254.112:40423 192.168.254.110 8000
```

Wireless ADB ports can change after reconnecting. Obtain the current address from Android Wireless debugging settings rather than saving it in source control.

## Production restriction

This HTTP workflow works only for debug development runs. Release builds require a stable public HTTPS `API_BASE_URL`, production signing, a reverse proxy, and appropriate server hardening. Do not distribute this debug build as a production application.
