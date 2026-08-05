#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"

cd "${project_dir}"
DESKPET_VISUAL_BASELINE_VERIFY=1 \
    swift test --filter PetVisualBaselineTests

echo "Visual baseline verification passed"
