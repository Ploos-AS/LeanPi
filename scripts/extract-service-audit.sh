#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 <serial-log> <output>" >&2; exit 2; }
log=$1
out=$2
[[ -f "$log" ]] || { echo "Serial log not found: $log" >&2; exit 1; }
start=$(grep -n -m1 '^LEANPI_SERVICE_AUDIT=1' "$log" | cut -d: -f1 || true)
[[ -n "$start" ]] || { echo "Service audit marker not found" >&2; exit 1; }
end=$(awk -v start="$start" 'NR >= start && /^LEANPI_SERVICE_AUDIT_END=1$/ { print NR; exit }' "$log")
[[ -n "$end" ]] || { echo "Service audit end marker not found" >&2; exit 1; }
sed -n "${start},${end}p" "$log" > "$out"
grep -q '^LEANPI_SERVICE_AUDIT=1$' "$out"
grep -q '^\[enabled\]$' "$out"
grep -q '^\[running\]$' "$out"
grep -q '^\[timers\]$' "$out"
grep -q '^LEANPI_SERVICE_AUDIT_END=1$' "$out"
echo "Service audit evidence: $out"
cat "$out"
