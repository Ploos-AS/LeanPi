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
# QEMU virt exposes the root disk through VirtIO MMIO.  Ensure the drivers
# needed to discover /dev/vda1 are present in the early userspace on armhf too.
mkdir -p "$rootfs/etc/initramfs-tools"
for module in virtio virtio_ring virtio_mmio virtio_blk; do
  grep -qxF "$module" "$rootfs/etc/initramfs-tools/modules" 2>/dev/null || echo "$module" >> "$rootfs/etc/initramfs-tools/modules"
done
chroot "$rootfs" update-initramfs -u -k all
kernel=$(find "$rootfs/boot" -maxdepth 1 -name "vmlinuz-*" -type f | sort -V | tail -1)
initrd=$(find "$rootfs/boot" -maxdepth 1 -name "initrd.img-*" -type f | sort -V | tail -1)
[[ -n "$kernel" && -n "$initrd" ]] || { echo "Kernel/initrd not found" >&2; exit 1; }
mkdir -p "$rootfs/etc/leanpi"
printf "KERNEL=%s\nINITRD=%s\n" "${kernel#$rootfs}" "${initrd#$rootfs}" > "$rootfs/etc/leanpi/qemu-virt-boot"
echo "virt kernel integration: PASS"
