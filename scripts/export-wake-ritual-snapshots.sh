#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
timestamp="$(date +%Y%m%d-%H%M%S)"
output_dir="${1:-${project_dir}/dist/wake-ritual-snapshots/${timestamp}}"

mkdir -p "${output_dir}"

cd "${project_dir}"
DESKPET_WAKE_RITUAL_SNAPSHOT_OUTPUT="${output_dir}" \
    swift test --filter PetWakeRitualVisualTests.exportsSequenceOnDemand

echo "Exported wake-ritual snapshots to ${output_dir}"
