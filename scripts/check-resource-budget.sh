#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 1 ]] || { echo "Usage: $0 <resource-baseline.txt>" >&2; exit 2; }
file=$1
[[ -f "$file" ]] || { echo "Baseline not found: $file" >&2; exit 1; }

source "$file"
max_memory_kib=${LEANPI_MAX_MEMORY_KIB:-40960}
max_root_bytes=${LEANPI_MAX_ROOT_BYTES:-524288000}
max_processes=${LEANPI_MAX_PROCESSES:-}
max_running_services=${LEANPI_MAX_RUNNING_SERVICES:-}

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

if [[ -n "$max_processes" ]]; then
  if (( process_count > max_processes )); then echo "RESOURCE FAIL: process_count=$process_count limit<=$max_processes" >&2; fail=1; else echo "RESOURCE PASS: process_count=$process_count limit<=$max_processes"; fi
else
  echo "RESOURCE INFO: process_count=$process_count (baseline only; no gate yet)"
fi
if [[ -n "$max_running_services" ]]; then
  if (( running_services > max_running_services )); then echo "RESOURCE FAIL: running_services=$running_services limit<=$max_running_services" >&2; fail=1; else echo "RESOURCE PASS: running_services=$running_services limit<=$max_running_services"; fi
else
  echo "RESOURCE INFO: running_services=$running_services (baseline only; no gate yet)"
fi

(( fail == 0 )) || exit 1
echo "LeanPi resource budget: PASS"
