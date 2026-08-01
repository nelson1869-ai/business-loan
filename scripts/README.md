# Lending Nelson Utility & Development Scripts

This directory contains utility scripts and local development launchers for the Lending Nelson platform.

---

## 1. Development Launcher Script (`start.sh` / `start.ps1`)

Local development launcher scripts to orchestrate backend and mobile application startup across Linux, macOS, WSL, Git Bash, and Windows PowerShell.

### Usage

**In PowerShell (Windows):**

```powershell
# Using Native PowerShell Launcher (Project Root)
.\start.ps1 [-Target <target>] [-App <officer|borrower|all>] [-Port <port>]

# Or running Bash script in PowerShell (requires Git Bash)
bash ./scripts/start.sh [target] [app-type] [port]
```

**In Bash (Linux / macOS / WSL / Git Bash):**

```bash
./scripts/start.sh [target] [app-type] [port]
```

### Parameters

- `target` / `-Target` (optional, default: `android`):
  - `android`: Targets `http://10.0.2.2:<port>` (Android Emulator default).
  - `ios` / `localhost`: Targets `http://localhost:<port>`.
  - `<IP_ADDRESS>`: Custom local network IP address (e.g. `192.168.1.100`).
- `app-type` / `-App` (optional, default: `borrower`):
  - `borrower`: Launches the Borrower Mobile Application (`apps/borrower_mobile`).
  - `officer`: Launches the Officer Mobile Application (Root repository `/`).
  - `all`: Launches both Officer and Borrower applications simultaneously.
- `port` / `-Port` (optional, default: `8000`): Backend server port.

### PowerShell Command Examples

```powershell
# Start backend & launch Borrower Mobile App on Android emulator
.\start.ps1 -Target android -App borrower
# or: bash ./scripts/start.sh android borrower

# Start backend & launch Officer Mobile App on Android emulator
.\start.ps1 -Target android -App officer
# or: bash ./scripts/start.sh android officer

# Start backend & launch both mobile applications
.\start.ps1 -Target android -App all
# or: bash ./scripts/start.sh android all

# Start backend & launch Borrower App for physical device on LAN IP
.\start.ps1 -Target 192.168.1.100 -App borrower -Port 8000
# or: bash ./scripts/start.sh 192.168.1.100 borrower 8000
```

### Automatic Process Management & Safety

- **Cleanup**: Stops pre-existing `uvicorn` backend processes and `flutter` app instances before launching to prevent double running.
- **Health Probing**: Probes `http://127.0.0.1:8000/health` and waits up to 15 seconds to ensure backend readiness before launching Flutter.

---

## 2. Physical Device Testing Script (`start-phone.ps1` / `start-phone.sh`)

Launcher script specifically for physical Android device testing over local Wi-Fi.

### Physical Device Usage in PowerShell

```powershell
.\start-phone.ps1 -PhoneAddress <PHONE_IP:PORT> -ServerIp <HOST_IP> [-App <officer|borrower|all>] [-Port <port>]
```

#### Physical Device Example

```powershell
.\start-phone.ps1 -PhoneAddress 192.168.1.50:40423 -ServerIp 192.168.1.100 -App all
```

---

## 3. n8n Workflow Security Validator (`validate_n8n_workflows.py`)

Python validator script that scans n8n workflow JSON export files to ensure no hardcoded API keys, secrets, Telegram chat IDs, sample PII, or pinned execution data are committed to version control.

### Security Validator Usage in PowerShell

```powershell
python scripts/validate_n8n_workflows.py [path/to/workflow.json ...]
```

### Rules Validated

- Unreplaced template placeholders (`YOUR_API_KEY`)
- Hardcoded API keys
- Hardcoded Telegram numeric chat IDs
- Pinned execution data (`pinData`)
- Philippine sample mobile numbers (`09XXXXXXXXX`)
