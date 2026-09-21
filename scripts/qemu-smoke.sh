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

case "$ARCH" in
  armel) qemu=qemu-system-arm ;;
  armhf) qemu=qemu-system-arm ;;
  arm64) qemu=qemu-system-aarch64 ;;
  *) echo "Unsupported QEMU architecture: $ARCH" >&2; exit 1 ;;
esac
command -v "$qemu" >/dev/null || { echo "Missing $qemu" >&2; exit 1; }

log="out/${board_id}/qemu-serial.log"
mkdir -p "$(dirname "$log")"
echo "QEMU smoke test: $board_id ($QEMU_MACHINE)"
echo "Serial log: $log"

set +e
qemu_args=(-M "$QEMU_MACHINE" -nographic -no-reboot -nic user)
case "$QEMU_MACHINE" in
  orangepi-pc) qemu_args+=(-drive "file=$image,format=raw,if=sd") ;;
  raspi0|raspi2b|raspi3b)
    rootfs_dir="out/${board_id}/rootfs"
    kernel=$(find "$rootfs_dir/boot" -maxdepth 1 \( -name 'vmlinuz-*' -o -name 'kernel.img' \) -type f | sort -V | tail -1)
    initrd=$(find "$rootfs_dir/boot" -maxdepth 1 -name 'initrd.img-*' -type f | sort -V | tail -1)
    [[ "$board_id" == raspi0 ]] && initrd=""
    if [[ "$board_id" == raspi0 ]]; then
      dtb=$(find "$rootfs_dir/boot" -maxdepth 1 -type f -name "${DTB}" | head -1)
    else
      dtb=$(find "$rootfs_dir/usr/lib" -type f -name "${DTB}" | head -1)
    fi
    [[ -n "$kernel" && -n "$dtb" ]] || { echo "Missing Raspberry Pi kernel/DTB" >&2; exit 1; }
    [[ "$board_id" == raspi0 || -n "$initrd" ]] || { echo "Missing Raspberry Pi initrd" >&2; exit 1; }
    qemu_args+=(
      -kernel "$kernel"
      -dtb "$dtb"
      -append "root=/dev/mmcblk0p1 rootwait rw console=${SERIAL_CONSOLE:-ttyAMA0},115200"
      -drive "file=$image,format=raw,if=sd"
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
  required_boot_signatures=('Starting kernel' 'Linux version' 'systemd')
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
for pattern in 'U-Boot' 'Starting kernel' 'Linux version' 'Waiting for root' 'leanpi-root' 'systemd'; do
  if grep -Fq "$pattern" "$log"; then
    echo "reached: $pattern" >&2
  else
    echo "missing: $pattern" >&2
  fi
done
echo '--- serial log tail ---' >&2
tail -n 80 "$log" >&2 || true

if [[ $rc -eq 124 || $rc -eq 137 || $rc -eq 143 ]]; then
  echo "QEMU smoke test: INCOMPLETE (timeout before LEANPI_BOOT_COMPLETE)" >&2
else
  echo "QEMU smoke test: INCOMPLETE (QEMU exit $rc)" >&2
fi
exit 1
