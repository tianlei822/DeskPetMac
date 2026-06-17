#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

product_name="DeskPetMac"
volume_name="DeskPet"
version="${1:-0.1.0}"
dist_dir="dist"
dmg_path="${dist_dir}/${product_name}-${version}.dmg"

# Build and bundle the signed .app, capturing its path from package-app.sh.
app_path="$(scripts/package-app.sh)"

if [[ ! -d "${app_path}" ]]; then
    echo "error: app bundle not found at ${app_path}" >&2
    exit 1
fi

mkdir -p "${dist_dir}"
rm -f "${dmg_path}"

# Stage the .app plus an /Applications shortcut for drag-to-install.
stage_dir="$(mktemp -d)"
trap 'rm -rf "${stage_dir}"' EXIT
cp -R "${app_path}" "${stage_dir}/"
ln -s /Applications "${stage_dir}/Applications"

hdiutil create \
    -volname "${volume_name}" \
    -srcfolder "${stage_dir}" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "${dmg_path}" >&2

echo "${PWD}/${dmg_path}"
