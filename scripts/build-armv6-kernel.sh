#!/usr/bin/env bash
set -euo pipefail

out=${1:-out/kernel-armv6}
kernel_repo=${KERNEL_REPO:-https://github.com/raspberrypi/linux.git}
kernel_ref=${KERNEL_REF:-rpi-6.12.y}
jobs=${JOBS:-$(nproc)}

mkdir -p "$out"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "Fetching Raspberry Pi Linux $kernel_ref"
git clone --depth 1 --branch "$kernel_ref" "$kernel_repo" "$work/linux"

export ARCH=arm
export CROSS_COMPILE=${CROSS_COMPILE:-arm-linux-gnueabihf-}

make -C "$work/linux" bcmrpi_defconfig
# QEMU Pi Zero direct-kernel boot has no initramfs, so root storage and ext4
# must be built into the kernel rather than available only as modules.
"$work/linux/scripts/config" --file "$work/linux/.config" \
  -e MMC -e MMC_BLOCK -e MMC_BCM2835 -e MMC_SDHCI -e MMC_SDHCI_PLTFM -e MMC_SDHCI_IPROC \
  -e EXT4_FS -e DEVTMPFS -e DEVTMPFS_MOUNT
make -C "$work/linux" olddefconfig
for opt in CONFIG_MMC CONFIG_MMC_BLOCK CONFIG_EXT4_FS CONFIG_DEVTMPFS CONFIG_DEVTMPFS_MOUNT; do
  grep -q "^${opt}=y$" "$work/linux/.config" || { echo "Required built-in kernel option missing: $opt" >&2; exit 1; }
done
make -C "$work/linux" -j"$jobs" zImage modules dtbs

mkdir -p "$out/boot"
cp "$work/linux/arch/arm/boot/zImage" "$out/boot/kernel.img"
cp "$work/linux/arch/arm/boot/dts/broadcom/bcm2835-rpi-zero.dtb" "$out/boot/"
make -C "$work/linux" INSTALL_MOD_PATH="$out/rootfs" modules_install

{
  echo "kernel_repo=$kernel_repo"
  echo "kernel_ref=$kernel_ref"
  git -C "$work/linux" rev-parse HEAD | sed 's/^/kernel_commit=/'
  sha256sum "$out/boot/kernel.img" | sed 's/^/kernel_sha256=/'
  sha256sum "$out/boot/bcm2835-rpi-zero.dtb" | sed 's/^/dtb_sha256=/'
} > "$out/BUILDINFO"

echo "ARMv6 kernel build: PASS"
