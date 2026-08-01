#!/usr/bin/env bash
# ==============================================================================
# Lending Nelson - Development Launcher Script (Linux / macOS / Git Bash / WSL)
# Supports launching Backend, Officer Mobile App, and Borrower Mobile App.
# ==============================================================================

set -euo pipefail

TARGET="${1:-android}"
APP_TYPE="${2:-borrower}"
PORT="${3:-8000}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/backend"
BORROWER_DIR="${PROJECT_ROOT}/apps/borrower_mobile"

# Detect Python venv executable
if [[ -f "${BACKEND_DIR}/.venv/Scripts/python.exe" ]]; then
  VENV_PYTHON="${BACKEND_DIR}/.venv/Scripts/python.exe"
elif [[ -f "${BACKEND_DIR}/.venv/bin/python" ]]; then
  VENV_PYTHON="${BACKEND_DIR}/.venv/bin/python"
else
  VENV_PYTHON="$(command -v python3 || command -v python)"
fi

# Resolve API Base URL
case "${TARGET}" in
  android|Android)
    API_URL="http://10.0.2.2:${PORT}"
    BIND_HOST="127.0.0.1"
    ;;
  ios|iOS|localhost|Localhost)
    API_URL="http://localhost:${PORT}"
    BIND_HOST="127.0.0.1"
    ;;
  http://*|https://*)
    API_URL="${TARGET%/}"
    BIND_HOST="0.0.0.0"
    ;;
  *)
    API_URL="http://${TARGET}:${PORT}"
    BIND_HOST="0.0.0.0"
    ;;
esac

echo "[INIT] Lending Nelson Local Development Launcher"
echo "Target: ${TARGET}"
echo "App Type: ${APP_TYPE}"
echo "API Base URL: ${API_URL}"

# Stop any pre-existing development processes for this project to prevent duplicate instances
stop_existing_processes() {
  echo "[CLEAN] Checking and stopping existing project processes..."
  
  # 1. Kill backend processes on port
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "${PORT}/tcp" >/dev/null 2>&1 || true
  fi
  
  # 2. Kill python uvicorn processes for this backend
  pkill -f "uvicorn.*app.main:app" >/dev/null 2>&1 || true
  
  # 3. Kill existing flutter processes for this project if not launching all
  if [[ "${APP_TYPE}" != "all" ]]; then
    pkill -f "flutter_tools.*API_BASE_URL=" >/dev/null 2>&1 || true
  fi
}

stop_existing_processes

# 1. Start Backend if targeting local host and backend is not already responding
if [[ "${API_URL}" =~ ^http://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:|$|/) ]]; then
  LOCAL_HEALTH_URL="http://127.0.0.1:${PORT}/health"
  if ! curl --fail --silent --show-error "${LOCAL_HEALTH_URL}" >/dev/null 2>&1; then
    echo "[START] Launching backend server on ${BIND_HOST}:${PORT}..."
    (
      cd "${BACKEND_DIR}"
      "${VENV_PYTHON}" -m uvicorn app.main:app --host "${BIND_HOST}" --port "${PORT}" > /tmp/lending_backend.log 2>&1 &
    )
    
    # Wait for backend health check
    for i in {1..15}; do
      if curl --fail --silent "${LOCAL_HEALTH_URL}" >/dev/null 2>&1; then
        echo "[OK] Backend server is healthy."
        break
      fi
      sleep 1
    done
  else
    echo "[OK] Backend server is already running."
  fi
fi

# 2. Launch requested Flutter application(s)
launch_officer() {
  echo "[START] Launching Officer Mobile App (Root)..."
  (
    cd "${PROJECT_ROOT}"
    flutter run --dart-define="API_BASE_URL=${API_URL}"
  )
}

launch_borrower() {
  echo "[START] Launching Borrower Mobile App (apps/borrower_mobile)..."
  (
    cd "${BORROWER_DIR}"
    flutter run --dart-define="API_BASE_URL=${API_URL}"
  )
}

case "${APP_TYPE}" in
  officer|Officer)
    launch_officer
    ;;
  borrower|Borrower)
    launch_borrower
    ;;
  all|All)
    echo "[START] Launching both Officer and Borrower applications..."
    launch_borrower &
    launch_officer
    ;;
  *)
    echo "Unknown app type: ${APP_TYPE}. Usage: $0 [target] [officer|borrower|all] [port]" >&2
    exit 1
    ;;
esac
