#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
timestamp="$(date +%Y%m%d-%H%M%S)"
output_dir="${1:-${project_dir}/dist/relationship-gesture-snapshots/${timestamp}}"

mkdir -p "${output_dir}"

cd "${project_dir}"
DESKPET_RELATIONSHIP_GESTURE_SNAPSHOT_OUTPUT="${output_dir}" \
    swift test --filter PetRelationshipGestureVisualTests.exportsSequenceOnDemand

echo "Exported relationship-gesture snapshots to ${output_dir}"
