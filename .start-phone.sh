#!/usr/bin/env bash
# Alias launcher pointing to start-phone.sh
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bash "${SCRIPT_DIR}/start-phone.sh" "$@"
