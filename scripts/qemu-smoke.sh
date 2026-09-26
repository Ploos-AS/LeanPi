#!/usr/bin/env bash
set -euo pipefail

usage() { echo "Usage: $0 <board-id> <image> [timeout-seconds]"; }
[[ $# -ge 2 ]] || { usage; exit 2; }

board_id=$1
image=$2
boot_timeout=${3:-90}
board_file="boards/${board_id}.conf"
[[ -f "$board_file" ]] || { echo "Unknown board: $board_id" >&2; exit 1; }
[[ -f "$image" ]] || { echo "Image not found: $image" >&2; exit 1; }
source "$board_file"

[[ "${EMULATOR:-}" == qemu ]] || { echo "$board_id is not a QEMU target" >&2; exit 1; }
[[ -n "${QEMU_MACHINE:-}" ]] || { echo "Missing QEMU_MACHINE" >&2; exit 1; }

case "$ARCH:$QEMU_MACHINE" in
  armhf:raspi3b) qemu=qemu-system-aarch64 ;;
  armel:*) qemu=qemu-system-arm ;;
  armhf:*) qemu=qemu-system-arm ;;
  arm64:*) qemu=qemu-system-aarch64 ;;
  *) echo "Unsupported QEMU architecture/machine: $ARCH/$QEMU_MACHINE" >&2; exit 1 ;;
esac
command -v "$qemu" >/dev/null || { echo "Missing $qemu" >&2; exit 1; }

log="out/${board_id}/qemu-serial.log"
mkdir -p "$(dirname "$log")"
echo "QEMU smoke test: $board_id ($QEMU_MACHINE)"
if [[ "$board_id" == raspi0 ]]; then
  echo "Pi Zero image partition diagnostics:"
  sfdisk -d "$image" || true
  fdisk -l "$image" || true
  echo "Pi Zero MBR signature and partition entry:"
  od -An -tx1 -j 446 -N 66 "$image" || true
  echo "Pi Zero partition start-sector signature:"
  od -An -tx1 -j $((8192 * 512)) -N 64 "$image" || true
  echo "Pi Zero host-side filesystem probe:"
  loop_probe=$(sudo losetup --find --show --partscan "$image")
  sudo blkid "$loop_probe" "${loop_probe}p1" || true
  sudo losetup -d "$loop_probe"
  # QEMU raspi0 currently exposes the SD card but not its MBR partition to
  # this ARMv6 guest kernel. Build a disposable whole-disk ext4 copy strictly
  # for emulator qualification; the released LeanPi image remains unchanged.
  qemu_image="out/${board_id}/leanpi-raspi0-qemu-root.img"
  truncate -s 1020M "$qemu_image"
  mkfs.ext4 -F -L leanpi-qemu-root "$qemu_image" >/dev/null
  loop_probe=$(sudo losetup --find --show --partscan "$image")
  qemu_root=$(sudo losetup --find --show "$qemu_image")
  sudo dd if="${loop_probe}p1" of="$qemu_root" bs=4M status=none conv=fsync
  sudo losetup -d "$qemu_root"
  sudo losetup -d "$loop_probe"
  echo "Pi Zero QEMU-only whole-disk rootfs: $qemu_image"
fi
echo "Serial log: $log"

set +e
qemu_args=(-M "$QEMU_MACHINE" -nographic -no-reboot)
case "$QEMU_MACHINE" in
  orangepi-pc|raspi2b|raspi3b) qemu_args+=(-m 1G) ;;
  raspi0) qemu_args+=(-m 512M) ;;
  *) qemu_args+=(-m 512M) ;;
esac
# Make CPU selection explicit where QEMU otherwise chooses an unsuitable execution state.
case "$ARCH:$QEMU_MACHINE" in
  arm64:virt) qemu_args+=(-cpu cortex-a57) ;;
  armhf:virt) qemu_args+=(-cpu cortex-a15) ;;
esac
# Some board models do not expose a QEMU NIC. Generic virt and sunxi do.
case "$QEMU_MACHINE" in
  virt|orangepi-pc) qemu_args+=(-nic user) ;;
esac
case "$QEMU_MACHINE" in
  orangepi-pc) qemu_args+=(-drive "file=$image,format=raw,if=sd") ;;
  raspi0|raspi2b|raspi3b)
    rootfs_dir="out/${board_id}/rootfs"
    if [[ "$board_id" == raspi0 ]]; then
      # The ARMv6 build installs the QEMU-tested zImage as kernel.img. Do not
      # let a future Debian vmlinuz sort after it and silently change the lane.
      kernel="$rootfs_dir/boot/kernel.img"
      [[ -s "$kernel" ]] || { echo "Missing Pi Zero ARMv6 kernel.img" >&2; exit 1; }
    else
      kernel=$(find "$rootfs_dir/boot" -maxdepth 1 -name 'vmlinuz-*' -type f | sort -V | tail -1)
    fi
    initrd=$(find "$rootfs_dir/boot" -maxdepth 1 -name 'initrd.img-*' -type f | sort -V | tail -1)
    echo "QEMU kernel: $kernel"
    [[ -n "$initrd" ]] && echo "QEMU initrd: $initrd"
    if command -v file >/dev/null 2>&1; then file "$kernel" || true; fi
    if [[ "$board_id" == raspi0 ]]; then
      dtb=$(find "$rootfs_dir/boot" -maxdepth 1 -type f -name "${DTB}" | head -1)
    else
      dtb=$(find "$rootfs_dir/usr/lib" -type f -name "${DTB}" | head -1)
    fi
    [[ -n "$kernel" && -n "$dtb" ]] || { echo "Missing Raspberry Pi kernel/DTB" >&2; exit 1; }
    [[ "$board_id" == raspi0 || -n "$initrd" ]] || { echo "Missing Raspberry Pi initrd" >&2; exit 1; }
    loopdev=$(sudo losetup --find --show --partscan "$image")
    trap 'sudo losetup -d "$loopdev" 2>/dev/null || true' EXIT
    root_partuuid=$(sudo blkid -s PARTUUID -o value "${loopdev}p1")
    [[ -n "$root_partuuid" ]] || { echo "Missing Raspberry Pi root PARTUUID" >&2; exit 1; }
    sudo losetup -d "$loopdev"
    trap - EXIT
    kernel_append="root=PARTUUID=$root_partuuid rootwait rw rootfstype=ext4 console=${SERIAL_CONSOLE:-ttyAMA0},115200"
    if [[ "$board_id" == raspi0 ]]; then
      # QEMU raspi0 exposes the SD image as mmcblk0. Use the stable emulated
      # device name here: the generated MBR PARTUUID is not propagated by this
      # machine model even though the partition itself is detected correctly.
      kernel_append="root=/dev/mmcblk0 rootwait rw rootfstype=ext4 console=${SERIAL_CONSOLE:-ttyAMA0},115200"
      # Make the earliest ARMv6 boot stage visible. If QEMU remains silent,
      # the failure is before Linux has initialized its normal serial console.
      kernel_append+=" earlycon=pl011,0x20201000 keep_bootcon ignore_loglevel"
    fi
    qemu_args+=(
      -kernel "$kernel"
      -dtb "$dtb"
      -append "$kernel_append"
      -drive "file=${qemu_image:-$image},format=raw,if=sd"
    )
    [[ -n "$initrd" ]] && qemu_args+=(-initrd "$initrd")
    ;;
  virt)
    rootfs_dir="out/${board_id}/rootfs"
    kernel=$(find "$rootfs_dir/boot" -maxdepth 1 -name 'vmlinuz-*' -type f | sort -V | tail -1)
    initrd=$(find "$rootfs_dir/boot" -maxdepth 1 -name 'initrd.img-*' -type f | sort -V | tail -1)
    [[ -n "$kernel" && -n "$initrd" ]] || { echo "Missing virt kernel/initrd" >&2; exit 1; }
    qemu_args+=(
      -kernel "$kernel"
      -initrd "$initrd"
      -append "root=/dev/vda1 rootwait rw console=${SERIAL_CONSOLE:-ttyAMA0},115200"
      -drive "file=$image,format=raw,if=none,id=rootdisk"
      -device virtio-blk-device,drive=rootdisk
    )
    ;;
  *) echo "No QEMU storage mapping defined for $QEMU_MACHINE" >&2; exit 1 ;;
esac
timeout --signal=TERM --kill-after=5 "${boot_timeout}s" "$qemu" "${qemu_args[@]}" 2>&1 | tee "$log"
rc=${PIPESTATUS[0]}
set -e

if grep -Eiq 'kernel panic|not syncing|emergency mode|failed to mount.*root|dependency failed for.*local file systems|cannot open root device|vfs: unable to mount root' "$log"; then
  echo "QEMU smoke test: FAIL (fatal boot signature)" >&2
  exit 1
fi
if grep -Fq 'LEANPI_BOOT_COMPLETE' "$log"; then
  required_boot_signatures=('Linux version' 'systemd')
  missing_boot_signatures=()
  for pattern in "${required_boot_signatures[@]}"; do
    grep -Fq "$pattern" "$log" || missing_boot_signatures+=("$pattern")
  done
  if (("${#missing_boot_signatures[@]}" == 0)); then
    echo "QEMU smoke test: PASS"
    exit 0
  fi
  echo "QEMU smoke test: FAIL (boot marker seen without complete boot evidence)" >&2
  printf 'Missing boot signature: %s\n' "${missing_boot_signatures[@]}" >&2
  exit 1
fi

echo '--- QEMU boot diagnostics ---' >&2
for pattern in 'U-Boot' 'Starting kernel' 'Linux version' 'mmc' 'leanpi-root' 'EXT4-fs' 'Mounted root' 'systemd' 'LEANPI_BOOT_COMPLETE'; do
  if grep -Fq "$pattern" "$log"; then
    echo "reached: $pattern" >&2
  else
    echo "missing: $pattern" >&2
  fi
done
echo '--- root/storage diagnostics ---' >&2
grep -Ei 'mmc|sdhci|leanpi-root|EXT4-fs|VFS:|root device|mounted root|waiting for root' "$log" | tail -n 60 >&2 || true
echo '--- serial log tail ---' >&2
tail -n 80 "$log" >&2 || true

if [[ $rc -eq 124 || $rc -eq 137 || $rc -eq 143 ]]; then
  echo "QEMU smoke test: INCOMPLETE (timeout before LEANPI_BOOT_COMPLETE)" >&2
else
  echo "QEMU smoke test: INCOMPLETE (QEMU exit $rc)" >&2
fi
exit 1
