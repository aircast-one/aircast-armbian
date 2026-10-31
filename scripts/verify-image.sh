#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
	echo "usage: $0 <image.img> <vX.Y.Z[-beta.N|-rc.N|-stage.N|-dev.N]> [aircastd deb version]" >&2
	exit 1
fi
img=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
version=$2
aircastd=${3:-}

case "$version" in
	*-dev.*)   distribution=development issuer=api.dev.aircast.one ;;
	*-stage.*) distribution=staging issuer=api.dev.aircast.one ;;
	*-rc.*)    distribution=testing issuer=api.dev.aircast.one ;;
	*)         distribution=stable issuer=api.aircast.one ;;
esac

docker run --rm --privileged -v "$(dirname "$img")":/img:ro debian:trixie bash -c '
nodes() { for p in /sys/block/${1#/dev/}/${1#/dev/}p*; do rm -f /dev/${p##*/}; mknod /dev/${p##*/} b $(tr : " " < $p/dev); done; }
L=$(losetup -fPr --show "/img/$1"); nodes $L; mkdir -p /r /b
mount -o ro ${L}p2 /r && mount -o ro ${L}p1 /b || { echo "mount failed"; exit 1; }
bad=""
[ "$(blkid -s LABEL -o value ${L}p1)" = bootfs ] || bad="$bad bootfs-label"
[ "$(blkid -s LABEL -o value ${L}p2)" = rootfs ] || bad="$bad rootfs-label"
[ "$(cat /r/etc/hostname)" = aircast ] || bad="$bad hostname"
for p in aircastd aircast-streamer tailscale wfb-ng cloud-init linux-sysctl-defaults; do
	dpkg-query --admindir=/r/var/lib/dpkg -W $p >/dev/null 2>&1 || bad="$bad pkg:$p"
done
ls /r/lib/modules/*/updates/dkms/88XXau_wfb.ko >/dev/null 2>&1 || bad="$bad dkms"
[ -e /b/uInitrd ] || bad="$bad uInitrd"
cat /b/armbianEnv.txt /b/extlinux/extlinux.conf 2>/dev/null | grep -q "cfg80211.ieee80211_regdom=" || bad="$bad regdom"
grep -q "\"distribution\": \"$2\"" /r/etc/aircast-release.json || bad="$bad distribution"
[ -z "$4" ] || grep -q "\"aircastd_version\": \"$4\"" /r/etc/aircast-release.json || bad="$bad aircastd"
grep -q "$3" /r/etc/aircast/oauth.json || bad="$bad issuer"
[ -L /r/etc/systemd/system/local-fs.target.wants/boot-firmware.mount ] || bad="$bad boot-firmware"
umount /r /b; losetup -d $L
[ -z "$bad" ] || { echo "MISSING:$bad"; exit 1; }
echo "image ok"' _ "$(basename "$img")" "$distribution" "$issuer" "$aircastd"
