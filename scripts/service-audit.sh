#!/bin/sh
set -eu
out=${1:-/tmp/leanpi-service-audit.txt}
mkdir -p "$(dirname "$out")"
{
  echo "LEANPI_SERVICE_AUDIT=1"
  echo "[enabled]"
  timeout 15s systemctl list-unit-files --type=service --state=enabled --no-legend 2>/dev/null | awk '{print $1}' | LC_ALL=C sort || true
  echo "[running]"
  timeout 15s systemctl list-units --type=service --state=running --no-legend 2>/dev/null | awk '{print $1}' | LC_ALL=C sort || true
  echo "[timers]"
  timeout 15s systemctl list-unit-files --type=timer --state=enabled --no-legend 2>/dev/null | awk '{print $1}' | LC_ALL=C sort || true
  echo "LEANPI_SERVICE_AUDIT_END=1"
} > "$out"
cat "$out"
