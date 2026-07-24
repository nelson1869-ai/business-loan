#!/usr/bin/env bash
# Professional Wireless Phone Launcher for Lending Nelson

PHONE_ADDRESS="${1:-192.168.254.112:40423}"
SERVER_IP="${2:-192.168.254.110}"
PORT="${3:-8000}"
API_URL="http://${SERVER_IP}:${PORT}"

ADB_EXE="D:/Development/Android/platform-tools/adb.exe"
if [ ! -f "$ADB_EXE" ]; then
    ADB_EXE="adb"
fi

echo "=================================================="
echo "  [INIT] Wireless Phone Launcher - Lending Nelson"
echo "=================================================="
echo " Target Phone  : ${PHONE_ADDRESS}"
echo " Server Base   : ${API_URL}"
echo ""

echo "[ADB] Connecting to wireless device at ${PHONE_ADDRESS}..."
"$ADB_EXE" connect "$PHONE_ADDRESS"

echo ""
echo "[FLUTTER] Launching app on phone [${PHONE_ADDRESS}]..."
flutter run -d "${PHONE_ADDRESS}" --dart-define=API_BASE_URL="${API_URL}"
