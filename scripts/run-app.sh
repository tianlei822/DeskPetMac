#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

app_path="$(scripts/package-app.sh)"
open -F "${app_path}"
