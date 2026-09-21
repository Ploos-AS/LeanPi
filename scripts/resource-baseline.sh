#!/usr/bin/env bash
set -euo pipefail

out=${1:-/tmp/leanpi-resource-baseline.txt}
mkdir -p "$(dirname "$out")"

mem_kib=$(awk '/^MemTotal:/ {total=$2} /^MemAvailable:/ {avail=$2} END {if (total && avail) print total-avail}' /proc/meminfo)
processes=$(ps -e --no-headers | wc -l)
enabled_units=$(systemctl list-unit-files --state=enabled --no-legend 2>/dev/null | wc -l || true)
running_services=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l || true)
root_bytes=$(df -B1 --output=used / | tail -1 | tr -d ' ')

{
  echo "LEANPI_RESOURCE_BASELINE=1"
  echo "memory_used_kib=$mem_kib"
  echo "process_count=$processes"
  echo "enabled_units=$enabled_units"
  echo "running_services=$running_services"
  echo "root_used_bytes=$root_bytes"
  echo "kernel=$(uname -r)"
  echo "architecture=$(uname -m)"
} | tee "$out"
