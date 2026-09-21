#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./build.sh <board-id> [--check-only]

M0 builder skeleton. It validates host prerequisites and board metadata.
M1 will add rootfs bootstrap, image partitioning and bootloader installation.
EOF
}

[[ $# -ge 1 ]] || { usage; exit 2; }

board_id=$1
shift
check_only=0

while (($#)); do
    case $1 in
        --check-only) check_only=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
    esac
    shift
done

board_file="boards/${board_id}.conf"
[[ -f $board_file ]] || { echo "Unknown board: $board_id" >&2; exit 1; }

# shellcheck disable=SC1090
source "$board_file"

required_vars=(BOARD_ID BOARD_NAME ARCH DEBIAN_ARCH SOC_FAMILY BOOTLOADER DTB KERNEL_FAMILY SUPPORT_TIER)
for var in "${required_vars[@]}"; do
    [[ -n ${!var:-} ]] || { echo "Missing board metadata: $var" >&2; exit 1; }
done

required_cmds=(bash awk sed grep sha256sum)
missing=()
for cmd in "${required_cmds[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done

if ((${#missing[@]})); then
    printf 'Missing required host commands:' >&2
    printf ' %s' "${missing[@]}" >&2
    printf '\n' >&2
    exit 1
fi

cat <<EOF
LeanPi M0 builder
Board:       $BOARD_NAME
Board ID:    $BOARD_ID
Architecture:$DEBIAN_ARCH
SoC family:  $SOC_FAMILY
Bootloader:  $BOOTLOADER
DTB:         $DTB
Kernel:      $KERNEL_FAMILY
Support:     $SUPPORT_TIER
EOF

if ((check_only)); then
    echo "M0 preflight: PASS"
    exit 0
fi

if ! command -v mmdebstrap >/dev/null 2>&1; then
    echo "mmdebstrap is required for image construction." >&2
    echo "Install it and rerun, or use --check-only for M0 metadata validation." >&2
    exit 1
fi

cat <<'EOF'
M0 builder skeleton: PASS
Image construction is intentionally deferred to M1.
EOF
