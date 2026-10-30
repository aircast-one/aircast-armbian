#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

ARMBIAN_REF=v26.5.1
PI_GEN="${PI_GEN:-../aircast-pi-gen}"

if [ $# -lt 1 ]; then
	echo "usage: $0 <orangepi5|rock-5b> [KEY=VALUE ...]" >&2
	exit 1
fi
board=$1
shift

if [ ! -d armbian ]; then
	git clone -q --depth 1 --branch "$ARMBIAN_REF" https://github.com/armbian/build.git armbian
elif [ "$(git -C armbian describe --tags --exact-match 2>/dev/null)" != "$ARMBIAN_REF" ]; then
	git -C armbian fetch -q --depth 1 origin tag "$ARMBIAN_REF"
	git -C armbian checkout -q "$ARMBIAN_REF"
fi

rm -rf armbian/userpatches
mkdir -p armbian/userpatches/aircast-pi-gen/stage2/04-cloud-init
cp -a userpatches/. armbian/userpatches/
cp -a "$PI_GEN/stage3" armbian/userpatches/aircast-pi-gen/
cp -a "$PI_GEN/stage2/04-cloud-init/files" armbian/userpatches/aircast-pi-gen/stage2/04-cloud-init/

docker run --rm --privileged ghcr.io/armbian/docker-armbian-build:armbian-ubuntu-noble-latest sh -c \
	'grep -qw ext4 /proc/filesystems || { truncate -s 8M /e && mkfs.ext4 -q /e && mount -o loop /e /mnt && umount /mnt; }'

case "${IMAGE_VERSION:-dev}" in
	dev)       release=() ;;
	*-dev.*)   release=(AIRCAST_DISTRIBUTION=development) ;;
	*-stage.*) release=(AIRCAST_DISTRIBUTION=staging) ;;
	*-rc.*)    release=(AIRCAST_DISTRIBUTION=testing) ;;
	*-beta.*)  release=(AIRCAST_DISTRIBUTION=stable AIRCAST_APT_CHANNEL=testing) ;;
	*)         release=(AIRCAST_DISTRIBUTION=stable) ;;
esac

exec ./armbian/compile.sh aircast \
	BOARD="$board" \
	IMAGE_VERSION="${IMAGE_VERSION:-dev}" \
	"${release[@]}" \
	PI_GEN_REF="$(git -C "$PI_GEN" rev-parse --abbrev-ref HEAD)" \
	PI_GEN_COMMIT="$(git -C "$PI_GEN" rev-parse HEAD)" \
	"$@"
