#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 <serial-log> <output>" >&2; exit 2; }
log=$1
out=$2
[[ -f "$log" ]] || { echo "Serial log not found: $log" >&2; exit 1; }

start=$(grep -n -m1 '^LEANPI_RESOURCE_BASELINE=1' "$log" | cut -d: -f1 || true)
[[ -n "$start" ]] || { echo "Resource baseline marker not found" >&2; exit 1; }

sed -n "${start},$((start+7))p" "$log" > "$out"
grep -q '^memory_used_kib=' "$out"
grep -q '^process_count=' "$out"
grep -q '^root_used_bytes=' "$out"
echo "Resource baseline evidence: $out"
cat "$out"
