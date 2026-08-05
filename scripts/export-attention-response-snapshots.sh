#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
timestamp="$(date +%Y%m%d-%H%M%S)"
output_dir="${1:-${project_dir}/dist/attention-response-snapshots/${timestamp}}"

mkdir -p "${output_dir}"

cd "${project_dir}"
DESKPET_ATTENTION_SNAPSHOT_OUTPUT="${output_dir}" \
    swift test --filter PetAttentionResponseVisualTests.exportsSequenceOnDemand

echo "Exported attention-response snapshots to ${output_dir}"
