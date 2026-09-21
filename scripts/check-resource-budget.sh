#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 1 ]] || { echo "Usage: $0 <resource-baseline.txt>" >&2; exit 2; }
file=$1
[[ -f "$file" ]] || { echo "Baseline not found: $file" >&2; exit 1; }

source "$file"
max_memory_kib=${LEANPI_MAX_MEMORY_KIB:-40960}
max_root_bytes=${LEANPI_MAX_ROOT_BYTES:-524288000}

fail=0
if (( memory_used_kib >= max_memory_kib )); then
  echo "RESOURCE FAIL: memory_used_kib=$memory_used_kib limit<$max_memory_kib" >&2
  fail=1
else
  echo "RESOURCE PASS: memory_used_kib=$memory_used_kib limit<$max_memory_kib"
fi
if (( root_used_bytes >= max_root_bytes )); then
  echo "RESOURCE FAIL: root_used_bytes=$root_used_bytes limit<$max_root_bytes" >&2
  fail=1
else
  echo "RESOURCE PASS: root_used_bytes=$root_used_bytes limit<$max_root_bytes"
fi

(( fail == 0 )) || exit 1
echo "LeanPi resource budget: PASS"
