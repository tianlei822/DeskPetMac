#!/usr/bin/env bash

set -euo pipefail

if [[ "${1:-}" != "--accept-current-rendering" ]]; then
    echo "Usage: scripts/update-visual-baselines.sh --accept-current-rendering" >&2
    exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
baseline_file="${project_dir}/Tests/DeskPetMacTests/VisualBaselines/deskpet-visual-fingerprints.json"

cd "${project_dir}"
DESKPET_VISUAL_BASELINE_UPDATE="${baseline_file}" \
    swift test --filter PetVisualBaselineTests

echo "Accepted current rendering at ${baseline_file}"
