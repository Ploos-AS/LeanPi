#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 <board-id> <rootfs-dir>" >&2; exit 2; }
board_id=$1
rootfs=$2
source "boards/${board_id}.conf"
[[ "${KERNEL_FAMILY:-}" == raspberrypi ]] || { echo "Not a Raspberry Pi target: $board_id" >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo "Must run as root" >&2; exit 1; }
case "$DEBIAN_ARCH" in
  armel) kernel_package=linux-image-marvell ;;
  armhf) kernel_package=linux-image-armmp ;;
  arm64) kernel_package=linux-image-arm64 ;;
  *) echo "Unsupported Raspberry Pi architecture: $DEBIAN_ARCH" >&2; exit 1 ;;
esac
if [[ "$DEBIAN_ARCH" == armel ]]; then
  echo "ARMv6 note: Debian armel userspace is supported, but Debian Trixie does not provide a BCM2835/Pi Zero kernel package." >&2
  echo "A dedicated ARMv6 kernel artifact is required before raspi0 can receive end-to-end PASS." >&2
  exit 3
fi
echo "Installing Debian Raspberry Pi qualification kernel: $kernel_package"
chroot "$rootfs" apt-get update
DEBIAN_FRONTEND=noninteractive chroot "$rootfs" apt-get install -y --no-install-recommends "$kernel_package"
kernel=$(find "$rootfs/boot" -maxdepth 1 -name "vmlinuz-*" -type f | sort -V | tail -1)
initrd=$(find "$rootfs/boot" -maxdepth 1 -name "initrd.img-*" -type f | sort -V | tail -1)
[[ -n "$kernel" && -n "$initrd" ]] || { echo "Kernel/initrd not found" >&2; exit 1; }
mkdir -p "$rootfs/etc/leanpi"
printf "KERNEL=%s\nINITRD=%s\nDTB=%s\n" "${kernel#$rootfs}" "${initrd#$rootfs}" "$DTB" > "$rootfs/etc/leanpi/qemu-raspi-boot"
echo "Raspberry Pi qualification kernel integration: PASS"
