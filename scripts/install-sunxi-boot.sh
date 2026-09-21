#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 3 ]] || { echo "Usage: $0 <board-id> <rootfs-dir> <image>" >&2; exit 2; }
board_id=$1
rootfs=$2
image=$3
source "boards/${board_id}.conf"

[[ "${KERNEL_FAMILY:-}" == sunxi ]] || { echo "Not a sunxi target: $board_id" >&2; exit 1; }
[[ -n "${UBOOT_DEFCONFIG:-}" ]] || { echo "Missing UBOOT_DEFCONFIG" >&2; exit 1; }
[[ -n "${DTB:-}" ]] || { echo "Missing DTB" >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo "Must run as root" >&2; exit 1; }

echo "Installing Debian sunxi kernel and U-Boot packages"
chroot "$rootfs" apt-get update
DEBIAN_FRONTEND=noninteractive chroot "$rootfs" apt-get install -y --no-install-recommends   linux-image-armmp u-boot-sunxi

kernel=$(basename "$(find "$rootfs/boot" -maxdepth 1 -name 'vmlinuz-*' -type f | sort -V | tail -1)")
initrd=$(basename "$(find "$rootfs/boot" -maxdepth 1 -name 'initrd.img-*' -type f | sort -V | tail -1)")
[[ -n "$kernel" && -n "$initrd" ]] || { echo "Kernel/initrd not found" >&2; exit 1; }

mkdir -p "$rootfs/boot/extlinux"
cat > "$rootfs/boot/extlinux/extlinux.conf" <<EOF
default leanpi
timeout 10

label leanpi
  linux /boot/$kernel
  initrd /boot/$initrd
  fdt /usr/lib/linux-image-${kernel#vmlinuz-}/$DTB
  append root=LABEL=leanpi-root rootwait rw console=${SERIAL_CONSOLE:-ttyS0},115200 console=tty1
EOF

# Debian's u-boot-sunxi package ships board-specific SPL+U-Boot images here.
uboot=$(find "$rootfs/usr/lib/u-boot" -path "*/u-boot-sunxi-with-spl.bin" -type f | grep -E "/${UBOOT_DEFCONFIG%_defconfig}/|/orangepi_(pc|zero)/" | head -1 || true)
[[ -n "$uboot" ]] || {
  echo "No packaged U-Boot image matched $UBOOT_DEFCONFIG" >&2
  find "$rootfs/usr/lib/u-boot" -name 'u-boot-sunxi-with-spl.bin' -print >&2 || true
  exit 1
}

echo "Writing $(basename "$(dirname "$uboot")") U-Boot at the Allwinner 8 KiB SD offset"
dd if="$uboot" of="$image" bs=1024 seek=8 conv=notrunc status=none
sync

echo "sunxi boot integration: PASS"
echo "Kernel: $kernel"
echo "DTB: $DTB"
echo "U-Boot: $uboot"
