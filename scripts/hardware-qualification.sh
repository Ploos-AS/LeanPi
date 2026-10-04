#!/usr/bin/env bash
set -euo pipefail

out=${1:-leanpi-hardware-qualification.txt}
board_id=${LEANPI_BOARD_ID:-orangepi-zero-lts}

[[ $EUID -eq 0 ]] || { echo "Run as root on the target board" >&2; exit 1; }
[[ -r /etc/os-release ]] || { echo "Missing /etc/os-release" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
"$script_dir/resource-baseline.sh" "$tmp/resource.txt" >/dev/null

serial_console=${LEANPI_SERIAL_CONSOLE:-ttyS0}
serial_state=absent
[[ -e /dev/$serial_console ]] && serial_state=present

network_if=
while IFS= read -r dev; do
  [[ $dev == lo ]] && continue
  network_if=$dev
  break
done < <(ls /sys/class/net)
network_state=absent
if [[ -n $network_if ]]; then
  network_state=$(cat "/sys/class/net/$network_if/operstate" 2>/dev/null || echo unknown)
fi

root_source=$(findmnt -n -o SOURCE /)
root_fstype=$(findmnt -n -o FSTYPE /)

{
  echo "LEANPI_HARDWARE_QUALIFICATION=1"
  echo "board_id=$board_id"
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "kernel=$(uname -r)"
  echo "architecture=$(uname -m)"
  echo "serial_console=$serial_console"
  echo "serial_device=$serial_state"
  echo "network_interface=${network_if:-none}"
  echo "network_state=$network_state"
  echo "root_source=$root_source"
  echo "root_fstype=$root_fstype"
  cat "$tmp/resource.txt"
} | tee "$out"

"$script_dir/check-resource-budget.sh" "$tmp/resource.txt"
echo "HARDWARE_QUALIFICATION_CAPTURE=PASS"
echo "Evidence: $out"
