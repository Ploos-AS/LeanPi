#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 <serial-log> <output>" >&2; exit 2; }
log=$1
out=$2
[[ -f "$log" ]] || { echo "Serial log not found: $log" >&2; exit 1; }

start=$(grep -n -m1 'LEANPI_RESOURCE_BASELINE=1' "$log" | cut -d: -f1 || true)
[[ -n "$start" ]] || { echo "Resource baseline marker not found" >&2; exit 1; }

tail -n +"$start" "$log" | awk '
  /LEANPI_RESOURCE_BASELINE=1/ { found=1; print "LEANPI_RESOURCE_BASELINE=1"; next }
  found && /^(memory_used_kib|process_count|enabled_units|running_services|root_used_bytes|kernel|architecture)=/ { print; count++ }
  found && count == 7 { exit }
' > "$out"

grep -q '^memory_used_kib=' "$out"
grep -q '^process_count=' "$out"
grep -q '^root_used_bytes=' "$out"
grep -q '^architecture=' "$out"
[[ $(wc -l < "$out") -eq 8 ]] || { echo "Incomplete resource baseline" >&2; cat "$out" >&2; exit 1; }
echo "Resource baseline evidence: $out"
cat "$out"
