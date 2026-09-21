#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 <serial-log> <output>" >&2; exit 2; }
log=$1
out=$2
[[ -f "$log" ]] || { echo "Serial log not found: $log" >&2; exit 1; }
start=$(grep -n -m1 '^LEANPI_SERVICE_AUDIT=1' "$log" | cut -d: -f1 || true)
[[ -n "$start" ]] || { echo "Service audit marker not found" >&2; exit 1; }
sed -n "${start},/^[^[]/p" "$log" | head -n 200 > "$out" || true
grep -q '^LEANPI_SERVICE_AUDIT=1' "$out"
grep -q '^\[enabled\]' "$out"
echo "Service audit evidence: $out"
cat "$out"
