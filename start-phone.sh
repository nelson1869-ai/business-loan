#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 4 ]]; then
  echo "Usage: $0 <phone-ip:adb-port> <server-ip> [backend-port] [officer|borrower|all]" >&2
  echo "Example: $0 192.168.254.112:40423 192.168.254.110 8000 borrower" >&2
  exit 2
fi

PHONE_ADDRESS="$1"
SERVER_IP="$2"
PORT="${3:-8000}"
APP_TYPE="${4:-officer}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BORROWER_DIR="${SCRIPT_DIR}/apps/borrower_mobile"

if [[ ! "$PHONE_ADDRESS" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}:[0-9]{1,5}$ ]]; then
  echo "Invalid phone address: $PHONE_ADDRESS" >&2
  exit 2
fi
if [[ ! "$SERVER_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  echo "Invalid server IP: $SERVER_IP" >&2
  exit 2
fi
if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "Invalid backend port: $PORT" >&2
  exit 2
fi

ADB_EXE="${LOCALAPPDATA:-}/Android/Sdk/platform-tools/adb.exe"
if [[ ! -f "$ADB_EXE" ]]; then
  ADB_EXE="$(command -v adb || true)"
fi
if [[ -z "$ADB_EXE" ]]; then
  echo "adb was not found. Install Android platform-tools or add adb to PATH." >&2
  exit 1
fi

API_URL="http://${SERVER_IP}:${PORT}"
echo "[DEV ONLY] Trusted local Wi-Fi launcher"
echo "Phone: ${PHONE_ADDRESS}"
echo "Backend: ${API_URL}"
echo "App Type: ${APP_TYPE}"

"$ADB_EXE" connect "$PHONE_ADDRESS"
if ! curl --fail --silent --show-error "${API_URL}/health" >/dev/null; then
  echo "Backend health check failed at ${API_URL}/health" >&2
  exit 1
fi

case "${APP_TYPE}" in
  borrower|Borrower)
    (
      cd "${BORROWER_DIR}"
      flutter run -d "$PHONE_ADDRESS" --dart-define="API_BASE_URL=${API_URL}"
    )
    ;;
  all|All)
    (
      cd "${BORROWER_DIR}"
      flutter run -d "$PHONE_ADDRESS" --dart-define="API_BASE_URL=${API_URL}" &
    )
    flutter run -d "$PHONE_ADDRESS" --dart-define="API_BASE_URL=${API_URL}"
    ;;
  *)
    flutter run -d "$PHONE_ADDRESS" --dart-define="API_BASE_URL=${API_URL}"
    ;;
esac