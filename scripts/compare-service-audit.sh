#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 <baseline> <current>" >&2; exit 2; }
baseline=$1
current=$2
for f in "$baseline" "$current"; do
  [[ -f "$f" ]] || { echo "Missing audit: $f" >&2; exit 1; }
done

section() {
  local name=$1 file=$2
  awk -v s="[$name]" '$0==s {on=1; next} /^\[/ {on=0} on && NF {print}' "$file" | LC_ALL=C sort -u
}

fail=0
for kind in enabled running timers; do
  b=$(mktemp); n=$(mktemp)
  section "$kind" "$baseline" > "$b"
  section "$kind" "$current" > "$n"
  added=$(comm -13 "$b" "$n" || true)
  if [[ -n "$added" ]]; then
    echo "SERVICE REGRESSION: new $kind units:" >&2
    printf '%s\n' "$added" >&2
    fail=1
  else
    echo "SERVICE PASS: no new $kind units"
  fi
  rm -f "$b" "$n"
done
(( fail == 0 )) || exit 1
echo "LeanPi service audit regression: PASS"
