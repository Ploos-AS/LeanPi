#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 <board-id> <rootfs-dir>" >&2; exit 2; }
board_id=$1
rootfs=$2
source "boards/${board_id}.conf"
[[ "${KERNEL_FAMILY:-}" == raspberrypi ]] || { echo "Not a Raspberry Pi target: $board_id" >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo "Must run as root" >&2; exit 1; }
case "$DEBIAN_ARCH" in
  armel)
    artifact_dir=${ARMV6_KERNEL_DIR:-out/kernel-armv6}
    [[ -s "$artifact_dir/boot/kernel.img" && -s "$artifact_dir/boot/bcm2835-rpi-zero.dtb" ]] || { echo "Missing ARMv6 kernel artifact in $artifact_dir" >&2; exit 3; }
    mkdir -p "$rootfs/boot" "$rootfs/etc/leanpi"
    cp "$artifact_dir/boot/kernel.img" "$rootfs/boot/kernel.img"
    cp "$artifact_dir/boot/bcm2835-rpi-zero.dtb" "$rootfs/boot/bcm2835-rpi-zero.dtb"
    if [[ -d "$artifact_dir/rootfs/lib/modules" ]]; then
      mkdir -p "$rootfs/lib"
      cp -a "$artifact_dir/rootfs/lib/modules" "$rootfs/lib/"
    fi
    printf "KERNEL=/boot/kernel.img\nDTB=/boot/bcm2835-rpi-zero.dtb\n" > "$rootfs/etc/leanpi/qemu-raspi-boot"
    echo "Raspberry Pi Zero ARMv6 kernel integration: PASS"
    exit 0
    ;;
  armhf) kernel_package=linux-image-armmp ;;
  arm64) kernel_package=linux-image-arm64 ;;
  *) echo "Unsupported Raspberry Pi architecture: $DEBIAN_ARCH" >&2; exit 1 ;;
esac
echo "Installing Debian Raspberry Pi qualification kernel: $kernel_package"
chroot "$rootfs" apt-get update
DEBIAN_FRONTEND=noninteractive chroot "$rootfs" apt-get install -y --no-install-recommends "$kernel_package"
kernel=$(find "$rootfs/boot" -maxdepth 1 -name "vmlinuz-*" -type f | sort -V | tail -1)
initrd=$(find "$rootfs/boot" -maxdepth 1 -name "initrd.img-*" -type f | sort -V | tail -1)
[[ -n "$kernel" && -n "$initrd" ]] || { echo "Kernel/initrd not found" >&2; exit 1; }
mkdir -p "$rootfs/etc/leanpi"
printf "KERNEL=%s\nINITRD=%s\nDTB=%s\n" "${kernel#$rootfs}" "${initrd#$rootfs}" "$DTB" > "$rootfs/etc/leanpi/qemu-raspi-boot"
echo "Raspberry Pi qualification kernel integration: PASS"
