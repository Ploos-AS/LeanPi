#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 <board-id> <rootfs-dir>" >&2; exit 2; }
board_id=$1
rootfs=$2
source "boards/${board_id}.conf"
[[ "${KERNEL_FAMILY:-}" == virt ]] || { echo "Not a virt target: $board_id" >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo "Must run as root" >&2; exit 1; }
case "$DEBIAN_ARCH" in
  armhf) kernel_package=linux-image-armmp ;;
  arm64) kernel_package=linux-image-arm64 ;;
  *) echo "Unsupported virt architecture: $DEBIAN_ARCH" >&2; exit 1 ;;
esac
echo "Installing generic QEMU virt kernel: $kernel_package"
chroot "$rootfs" apt-get update
DEBIAN_FRONTEND=noninteractive chroot "$rootfs" apt-get install -y --no-install-recommends "$kernel_package"
kernel=$(find "$rootfs/boot" -maxdepth 1 -name "vmlinuz-*" -type f | sort -V | tail -1)
initrd=$(find "$rootfs/boot" -maxdepth 1 -name "initrd.img-*" -type f | sort -V | tail -1)
[[ -n "$kernel" && -n "$initrd" ]] || { echo "Kernel/initrd not found" >&2; exit 1; }
mkdir -p "$rootfs/etc/leanpi"
printf "KERNEL=%s\nINITRD=%s\n" "${kernel#$rootfs}" "${initrd#$rootfs}" > "$rootfs/etc/leanpi/qemu-virt-boot"
echo "virt kernel integration: PASS"
