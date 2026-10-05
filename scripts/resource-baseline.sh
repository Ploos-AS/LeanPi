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
enabled_units=unknown
if output=$(timeout 30s systemctl list-unit-files --state=enabled --no-legend 2>/dev/null); then
  enabled_units=$(printf '%s\n' "$output" | awk 'NF {count++} END {print count+0}')
fi
running_services=unknown
if output=$(timeout 30s systemctl list-units --type=service --state=running --no-legend 2>/dev/null); then
  running_services=$(printf '%s\n' "$output" | awk 'NF {count++} END {print count+0}')
fi
root_bytes=$(df -B1 --output=used / | tail -1 | tr -d ' ')
# Record writes completed by the block device backing /. This is cumulative
# since boot and is intentionally evidence-only for now: QEMU/device models can
# differ, so M1.1 first establishes stable per-machine baselines before gating.
root_source=$(findmnt -n -o SOURCE / 2>/dev/null || true)
root_partition=$(basename "$root_source")
root_device=
if [[ -n "$root_partition" && -e "/sys/class/block/$root_partition" ]]; then
  sys_block=$(readlink -f "/sys/class/block/$root_partition")
  if [[ -f "/sys/class/block/$root_partition/partition" ]]; then
    root_device=$(basename "$(dirname "$sys_block")")
  else
    root_device=$root_partition
  fi
fi
sectors_written=
if [[ -n "$root_device" && -r /proc/diskstats ]]; then
  sectors_written=$(awk -v dev="$root_device" '$3 == dev {print $10; exit}' /proc/diskstats)
fi
[[ "$sectors_written" =~ ^[0-9]+$ ]] || sectors_written=unknown

# Emit evidence for memory work without changing the resource gate. These
# snapshots make it possible to distinguish userspace RSS from kernel/slab/cache
# pressure on board-specific QEMU machines.
echo "LEANPI_MEMORY_DIAGNOSTICS=1"
grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|Active|Inactive|Active\(anon\)|Inactive\(anon\)|Active\(file\)|Inactive\(file\)|AnonPages|Mapped|Shmem|KReclaimable|SReclaimable|SUnreclaim|Slab|KernelStack|PageTables|Percpu|VmallocUsed):' /proc/meminfo || true
ps -e -o pid=,comm=,rss= --sort=-rss 2>/dev/null | head -n 15 || true
echo "LEANPI_MODULE_DIAGNOSTICS=1"
if [[ -r /proc/modules ]]; then
  while IFS= read -r module; do
    printf '%s\n' "$module" || true
  done < /proc/modules
fi
echo "LEANPI_UDEV_DIAGNOSTICS=1"
for dir in /usr/lib/udev/rules.d /etc/udev/rules.d; do
  if [[ -d "$dir" ]]; then
    find "$dir" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort || true
  fi
done
echo "LEANPI_MEMORY_DIAGNOSTICS_END=1"

{
  echo "LEANPI_RESOURCE_BASELINE=1"
  echo "memory_used_kib=$mem_kib"
  echo "process_count=$processes"
  echo "enabled_units=$enabled_units"
  echo "running_services=$running_services"
  echo "root_used_bytes=$root_bytes"
  echo "root_sectors_written_since_boot=$sectors_written"
  echo "kernel=$(uname -r)"
  echo "architecture=$(uname -m)"
} | tee "$out"
