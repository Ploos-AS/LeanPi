#!/usr/bin/env bash
set -euo pipefail

out=${1:-/tmp/leanpi-resource-baseline.txt}
mkdir -p "$(dirname "$out")"

# Sample memory several times after the qualification service starts. QEMU board
# boots have small transient swings; the minimum is a better idle baseline than
# one scheduler-dependent instant while still measuring real MemAvailable.
mem_kib=
# Let boot-time one-shot work and kernel deferred probes settle before measuring
# the steady idle footprint. This does not change the budget; it only avoids
# treating short-lived boot allocations as resident LeanPi memory.
sleep 10
for _ in 1 2 3; do
  sample=$(awk '/^MemTotal:/ {total=$2} /^MemAvailable:/ {avail=$2} END {if (total && avail) print total-avail}' /proc/meminfo)
  [[ "$sample" =~ ^[0-9]+$ ]] || { echo "Unable to read memory baseline" >&2; exit 1; }
  if [[ -z "$mem_kib" || "$sample" -lt "$mem_kib" ]]; then mem_kib=$sample; fi
  sleep 1
done
processes=$(ps -e --no-headers | wc -l)
enabled_units=$(systemctl list-unit-files --state=enabled --no-legend 2>/dev/null | wc -l || true)
running_services=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l || true)
root_bytes=$(df -B1 --output=used / | tail -1 | tr -d ' ')

# Emit evidence for memory work without changing the resource gate. These
# snapshots make it possible to distinguish userspace RSS from kernel/slab/cache
# pressure on board-specific QEMU machines.
echo "LEANPI_MEMORY_DIAGNOSTICS=1"
grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SReclaimable|SUnreclaim|Slab|KernelStack|PageTables):' /proc/meminfo || true
ps -e -o pid=,comm=,rss= --sort=-rss 2>/dev/null | head -n 15 || true
echo "LEANPI_MEMORY_DIAGNOSTICS_END=1"

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
