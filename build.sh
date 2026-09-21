#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo 'Usage: sudo ./build.sh <board-id> [--check-only] [--rootfs-dir PATH] [--image PATH]'
}
[[ $# -ge 1 ]] || { usage; exit 2; }
board_id=$1; shift
check_only=0; rootfs_dir=; image_path=
while (($#)); do
 case $1 in
  --check-only) check_only=1 ;;
  --rootfs-dir) shift; [[ $# -ge 1 ]] || exit 2; rootfs_dir=$1 ;;
  --image) shift; [[ $# -ge 1 ]] || exit 2; image_path=$1 ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unknown argument: $1" >&2; exit 2 ;;
 esac
 shift
done

board_file="boards/${board_id}.conf"
[[ -f $board_file ]] || { echo "Unknown board: $board_id" >&2; exit 1; }
source "$board_file"

required_vars=(BOARD_ID BOARD_NAME ARCH DEBIAN_ARCH SOC_FAMILY BOOTLOADER DTB KERNEL_FAMILY SUPPORT_TIER)
for var in "${required_vars[@]}"; do [[ -n ${!var:-} ]] || { echo "Missing board metadata: $var" >&2; exit 1; }; done

required_cmds=(bash awk sed grep sha256sum)
((check_only)) || required_cmds+=(mmdebstrap truncate sfdisk losetup mkfs.ext4 mount umount rsync)
missing=()
for cmd in "${required_cmds[@]}"; do command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd"); done
(("${#missing[@]}" == 0)) || { printf 'Missing required host commands: %s\n' "${missing[*]}" >&2; exit 1; }

printf 'LeanPi M1.1 builder\nBoard: %s\nArchitecture: %s\nSoC family: %s\nBootloader: %s\nDTB: %s\nKernel: %s\nSupport: %s\n' "$BOARD_NAME" "$DEBIAN_ARCH" "$SOC_FAMILY" "$BOOTLOADER" "$DTB" "$KERNEL_FAMILY" "$SUPPORT_TIER"
((check_only)) && { echo 'M1.1 preflight: PASS'; exit 0; }
[[ $EUID -eq 0 ]] || { echo 'LeanPi image build must run as root.' >&2; exit 1; }

release=${DEBIAN_RELEASE:-trixie}
mirror=${DEBIAN_MIRROR:-https://deb.debian.org/debian}
out_dir="out/${BOARD_ID}"
rootfs_dir=${rootfs_dir:-"${out_dir}/rootfs"}
image_path=${image_path:-"${out_dir}/leanpi-${BOARD_ID}.img"}
image_size_mb=${IMAGE_SIZE_MB:-768}
mkdir -p "$out_dir"

if [[ -e $rootfs_dir ]]; then
 [[ -d $rootfs_dir && -z $(find "$rootfs_dir" -mindepth 1 -maxdepth 1 -print -quit) ]] || { echo "Refusing to bootstrap into non-empty path: $rootfs_dir" >&2; exit 1; }
else
 mkdir -p "$rootfs_dir"
fi

echo "Bootstrapping Debian $release ($DEBIAN_ARCH) into $rootfs_dir"
mmdebstrap --architectures="$DEBIAN_ARCH" --variant=minbase --components=main --include=systemd-sysv,ca-certificates,iproute2,ifupdown,isc-dhcp-client,dropbear "$release" "$rootfs_dir" "$mirror"

mkdir -p "$rootfs_dir/etc/leanpi"
printf 'LEANPI_BOARD=%s\nLEANPI_BOARD_NAME="%s"\nLEANPI_DEBIAN_RELEASE=%s\nLEANPI_ARCH=%s\nLEANPI_SUPPORT_TIER=%s\n' "$BOARD_ID" "$BOARD_NAME" "$release" "$DEBIAN_ARCH" "$SUPPORT_TIER" > "$rootfs_dir/etc/leanpi/release"
printf 'leanpi\n' > "$rootfs_dir/etc/hostname"
printf 'auto lo\niface lo inet loopback\n\nallow-hotplug eth0\niface eth0 inet dhcp\n' > "$rootfs_dir/etc/network/interfaces"

echo "Creating ${image_size_mb} MiB raw image: $image_path"
rm -f "$image_path"
truncate -s "${image_size_mb}M" "$image_path"
printf 'label: dos\nunit: sectors\n\nstart=8192, type=83, bootable\n' | sfdisk "$image_path" >/dev/null

loopdev=
mnt=
cleanup() {
 set +e
 [[ -n $mnt ]] && mountpoint -q "$mnt" && umount "$mnt"
 [[ -n $mnt && -d $mnt ]] && rmdir "$mnt"
 [[ -n $loopdev ]] && losetup -d "$loopdev"
}
trap cleanup EXIT
loopdev=$(losetup --find --show --partscan "$image_path")
mkfs.ext4 -F -L leanpi-root "${loopdev}p1" >/dev/null
mnt=$(mktemp -d)
mount "${loopdev}p1" "$mnt"
rsync -aHAX --numeric-ids "$rootfs_dir/" "$mnt/"
sync
umount "$mnt"
rmdir "$mnt"; mnt=
losetup -d "$loopdev"; loopdev=

echo 'LeanPi M1.1 rootfs + raw filesystem image: PASS'
echo "Image: $image_path"
echo 'NOTE: image is not bootable yet; U-Boot, kernel and DTB integration is the next M1 step.'
du -sh "$rootfs_dir"
sha256sum "$image_path" | tee "${image_path}.sha256"
