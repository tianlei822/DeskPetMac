#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
timestamp="$(date +%Y%m%d-%H%M%S)"
output_dir="${1:-${project_dir}/dist/unified-rig-snapshots/${timestamp}}"

mkdir -p "${output_dir}"

cd "${project_dir}"
DESKPET_UNIFIED_RIG_SNAPSHOT_OUTPUT="${output_dir}" \
    swift test --disable-sandbox \
    --filter PetRootMotionVisualTests/exportsUnifiedRigOnDemand

echo "Exported unified-rig gait sequence to ${output_dir}"
