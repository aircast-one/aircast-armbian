#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

PI_GEN="${PI_GEN:-../aircast-pi-gen}"

if [ $# -lt 2 ]; then
	echo "usage: $0 <board> <vX.Y.Z[-dev.N|-stage.N|-rc.N|-beta.N]> [--yes] [--force]" >&2
	exit 1
fi
board=$1
version=$2
shift 2

img=$(ls -t armbian/output/images/Armbian-unofficial_"${version}"_"${board^}"_*.img 2>/dev/null | head -1 || true)
[ -n "$img" ] || { echo "No ${board} image built as ${version} — run: IMAGE_VERSION=${version} ./build.sh ${board}" >&2; exit 1; }

deploy="$PWD/armbian/output/publish/${board}"
rm -rf "$deploy"
mkdir -p "$deploy"
xz -T0 -c "$img" > "$deploy/$(basename "$img").xz"
printf '%s %s\n' "$version" "$(basename "$img").xz" > "$deploy/.publish-version"

DEPLOY_DIR="$deploy" URL_PATH="$board" ASSET_PREFIX="aircast-${board}" exec "$PI_GEN/scripts/publish-local.sh" "$version" "$@"
