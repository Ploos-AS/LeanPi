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
# QEMU Pi Zero direct-kernel boot still needs root storage and ext4 built in:
# the ARMv6 artifact is intentionally self-contained and does not depend on
# Debian's initramfs module set.
"$work/linux/scripts/config" --file "$work/linux/.config" \
  -e MMC -e MMC_BLOCK -e MMC_BCM2835 -e MMC_SDHCI -e MMC_SDHCI_PLTFM -e MMC_SDHCI_IPROC \
  -e PARTITION_ADVANCED -e MSDOS_PARTITION -e EFI_PARTITION -e BLOCK -e BLK_DEV_SD \
  -e EXT4_FS -e DEVTMPFS -e DEVTMPFS_MOUNT \
  -d MFD_BCM2835_PM -d RASPBERRYPI_POWER -d BCM2835_POWER
# QEMU raspi0 lacks the BCM2835 firmware power-management MMIO block expected
# by the current Raspberry Pi kernel. Disable both the MFD parent and Raspberry
# Pi power-domain driver in this emulator qualification kernel. Physical Pi Zero
# qualification must validate the normal hardware configuration.
make -C "$work/linux" olddefconfig

# olddefconfig can reselect drivers through Kconfig dependencies. Assert that
# the raspi0-incompatible power driver is really absent instead of silently
# producing another kernel that panics in bcm2835_power_probe.
for opt in CONFIG_MFD_BCM2835_PM CONFIG_RASPBERRYPI_POWER CONFIG_BCM2835_POWER; do
  if grep -q "^${opt}=y$" "$work/linux/.config"; then
    echo "QEMU-incompatible kernel option remained enabled: $opt" >&2
    exit 1
  fi
done
for opt in CONFIG_BLOCK CONFIG_MMC CONFIG_MMC_BLOCK CONFIG_MMC_BLOCK_MINORS CONFIG_MSDOS_PARTITION CONFIG_EFI_PARTITION CONFIG_EXT4_FS CONFIG_DEVTMPFS CONFIG_DEVTMPFS_MOUNT; do
  grep -q "^${opt}=y$" "$work/linux/.config" || { echo "Required built-in kernel option missing: $opt" >&2; exit 1; }
done
grep -E '^CONFIG_(BLOCK|PARTITION_ADVANCED|MSDOS_PARTITION|EFI_PARTITION|MMC|MMC_BLOCK|MMC_BLOCK_MINORS)=' "$work/linux/.config" || true
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
