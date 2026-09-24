#!/usr/bin/env bash
set -euo pipefail
usage(){ echo 'Usage: sudo ./build.sh <board-id> [--check-only] [--rootfs-dir PATH] [--image PATH]'; }
[[ $# -ge 1 ]] || { usage; exit 2; }
board_id=$1; shift; check_only=0; rootfs_dir=; image_path=
while (($#)); do case $1 in --check-only) check_only=1;; --rootfs-dir) shift; rootfs_dir=$1;; --image) shift; image_path=$1;; -h|--help) usage; exit 0;; *) echo "Unknown argument: $1" >&2; exit 2;; esac; shift; done
board_file="boards/${board_id}.conf"; [[ -f $board_file ]] || { echo "Unknown board: $board_id" >&2; exit 1; }; source "$board_file"
required_vars=(BOARD_ID BOARD_NAME ARCH DEBIAN_ARCH SOC_FAMILY BOOTLOADER DTB KERNEL_FAMILY SUPPORT_TIER)
for var in "${required_vars[@]}"; do [[ -n ${!var:-} ]] || { echo "Missing board metadata: $var" >&2; exit 1; }; done
required_cmds=(bash awk sed grep sha256sum); ((check_only)) || required_cmds+=(mmdebstrap truncate sfdisk losetup mkfs.ext4 mount umount rsync)
missing=(); for cmd in "${required_cmds[@]}"; do command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd"); done
(("${#missing[@]}"==0)) || { printf 'Missing required host commands: %s\n' "${missing[*]}" >&2; exit 1; }
printf 'LeanPi M1.2 builder\nBoard: %s\nArchitecture: %s\nSoC family: %s\nBootloader: %s\nDTB: %s\nKernel: %s\nSupport: %s\n' "$BOARD_NAME" "$DEBIAN_ARCH" "$SOC_FAMILY" "$BOOTLOADER" "$DTB" "$KERNEL_FAMILY" "$SUPPORT_TIER"
((check_only)) && { echo 'M1.2 preflight: PASS'; exit 0; }
[[ $EUID -eq 0 ]] || { echo 'LeanPi image build must run as root.' >&2; exit 1; }
release=${DEBIAN_RELEASE:-${BASE_RELEASE:-trixie}}; mirror=${DEBIAN_MIRROR:-https://deb.debian.org/debian}; out_dir="out/${BOARD_ID}"
rootfs_dir=${rootfs_dir:-"${out_dir}/rootfs"}; image_path=${image_path:-"${out_dir}/leanpi-${BOARD_ID}.img"}; image_size_mb=${IMAGE_SIZE_MB:-768}; mkdir -p "$out_dir"
if [[ -e $rootfs_dir ]]; then [[ -d $rootfs_dir && -z $(find "$rootfs_dir" -mindepth 1 -maxdepth 1 -print -quit) ]] || { echo "Refusing non-empty path: $rootfs_dir" >&2; exit 1; }; else mkdir -p "$rootfs_dir"; fi
echo "Bootstrapping Debian $release ($DEBIAN_ARCH)"
mmdebstrap --architectures="$DEBIAN_ARCH" --variant=minbase --components=main --include=systemd-sysv,ca-certificates,iproute2,ifupdown,isc-dhcp-client,dropbear,procps "$release" "$rootfs_dir" "$mirror"
mkdir -p "$rootfs_dir/etc/leanpi"
printf 'LEANPI_BOARD=%s\nLEANPI_BOARD_NAME="%s"\nLEANPI_DEBIAN_RELEASE=%s\nLEANPI_ARCH=%s\nLEANPI_SUPPORT_TIER=%s\n' "$BOARD_ID" "$BOARD_NAME" "$release" "$DEBIAN_ARCH" "$SUPPORT_TIER" > "$rootfs_dir/etc/leanpi/release"
printf 'leanpi\n' > "$rootfs_dir/etc/hostname"; printf 'auto lo\niface lo inet loopback\n\nallow-hotplug eth0\niface eth0 inet dhcp\n' > "$rootfs_dir/etc/network/interfaces"
# Emit the qualification marker as soon as systemd is running on the real
# root filesystem. Avoid basic.target: H3 device/udev settling is very slow in QEMU.
cat > "$rootfs_dir/etc/systemd/system/leanpi-boot-complete.service" <<'EOF'
[Unit]
Description=LeanPi qualification boot marker
DefaultDependencies=no
After=systemd-remount-fs.service
Before=systemd-udev-trigger.service multi-user.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo LEANPI_BOOT_COMPLETE > /dev/console; touch /run/leanpi-boot-complete'
EOF
cat > "$rootfs_dir/etc/systemd/system/leanpi-qualification-metrics.service" <<'EOF'
[Unit]
Description=LeanPi qualification resource metrics
After=leanpi-boot-complete.service systemd-udev-trigger.service
Wants=leanpi-boot-complete.service
Before=multi-user.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'if [ -x /usr/local/sbin/leanpi-resource-baseline ]; then /usr/local/sbin/leanpi-resource-baseline /run/leanpi-resource-baseline.txt > /dev/console 2>&1 || true; fi; if [ -x /usr/local/sbin/leanpi-service-audit ]; then /usr/local/sbin/leanpi-service-audit /run/leanpi-service-audit.txt > /dev/console 2>&1 || true; fi'
EOF
mkdir -p "$rootfs_dir/etc/systemd/system/sysinit.target.wants" "$rootfs_dir/etc/systemd/system/multi-user.target.wants"
ln -s ../leanpi-boot-complete.service "$rootfs_dir/etc/systemd/system/sysinit.target.wants/leanpi-boot-complete.service"
ln -s ../leanpi-qualification-metrics.service "$rootfs_dir/etc/systemd/system/multi-user.target.wants/leanpi-qualification-metrics.service"

# Keep emulated qualification focused on headless/server boot.  The generic
# armmp kernel otherwise spends minutes probing H3 multimedia devices that are
# irrelevant to LeanPi's serial CI gate.
if [[ "${SUPPORT_TIER:-}" == emulated && "${SOC_FAMILY:-}" == sun8i ]]; then
  mkdir -p "$rootfs_dir/etc/modprobe.d"
  cat > "$rootfs_dir/etc/modprobe.d/leanpi-qemu-headless.conf" <<'EOF'
# LeanPi QEMU qualification: skip nonessential H3 multimedia stacks.
blacklist lima
blacklist sunxi_cedrus
blacklist sun8i_drm_hdmi
blacklist sun8i_mixer
blacklist sun4i_tcon
blacklist sun4i_drm
blacklist sunxi_ir
EOF
fi

echo "Creating ${image_size_mb} MiB raw image: $image_path"; rm -f "$image_path"; truncate -s "${image_size_mb}M" "$image_path"; printf 'label: dos\nunit: sectors\n\nstart=8192, type=83, bootable\n' | sfdisk "$image_path" >/dev/null
# Install board-family boot payload before copying the completed rootfs.
if [[ $KERNEL_FAMILY == sunxi ]]; then bash scripts/install-sunxi-boot.sh "$BOARD_ID" "$rootfs_dir" "$image_path"; fi
install -Dm755 scripts/leanpi-config "$rootfs_dir/usr/local/sbin/leanpi-config"
mkdir -p "$rootfs_dir/etc/systemd/journald.conf.d"
cat > "$rootfs_dir/etc/systemd/journald.conf.d/leanpi.conf" <<'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=8M
RuntimeKeepFree=16M
Compress=yes
EOF

# Keep temporary writes off flash without allowing tmpfs to consume unbounded RAM.
mkdir -p "$rootfs_dir/etc/systemd/system/tmp.mount.d" "$rootfs_dir/etc/systemd/system/local-fs.target.wants"
cat > "$rootfs_dir/etc/systemd/system/tmp.mount.d/leanpi.conf" <<'EOF'
[Mount]
Options=mode=1777,strictatime,nosuid,nodev,size=32M,nr_inodes=16k
EOF
ln -sf ../tmp.mount "$rootfs_dir/etc/systemd/system/local-fs.target.wants/tmp.mount"

# LeanPi is headless-first. Keep the serial console plus tty1 for local recovery,
# but do not spend RAM/processes on five additional virtual-console gettys.
mkdir -p "$rootfs_dir/etc/systemd/system/getty.target.wants"
for tty in tty2 tty3 tty4 tty5 tty6; do
  ln -sf /dev/null "$rootfs_dir/etc/systemd/system/getty.target.wants/getty@$tty.service"
done

# Keep /var/tmp persistent: applications may rely on data surviving reboot.
# Bound APT's package cache instead of spending scarce RAM on another tmpfs.
mkdir -p "$rootfs_dir/etc/apt/apt.conf.d"
cat > "$rootfs_dir/etc/apt/apt.conf.d/90leanpi-cache" <<'EOF'
APT::Keep-Downloaded-Packages "false";
Binary::apt::APT::Keep-Downloaded-Packages "false";
Acquire::Languages "none";
EOF

# Periodic package-list cleanup is intentionally not implemented as a daemon/timer.
# Explicit package operations remain predictable and background wakeups stay at zero.

# Headless small-board defaults: disable background facilities that provide no
# value in LeanPi Base. Masking is deterministic and users can explicitly unmask.
for unit in     apt-daily.service apt-daily.timer     apt-daily-upgrade.service apt-daily-upgrade.timer     man-db.service man-db.timer     e2scrub_all.service e2scrub_all.timer     dpkg-db-backup.service dpkg-db-backup.timer     fstrim.service fstrim.timer
do
    ln -sf /dev/null "$rootfs_dir/etc/systemd/system/$unit"
done

install -Dm755 scripts/leanpi-firstboot "$rootfs_dir/usr/local/sbin/leanpi-firstboot"
install -Dm644 systemd/leanpi-firstboot.service "$rootfs_dir/etc/systemd/system/leanpi-firstboot.service"
mkdir -p "$rootfs_dir/etc/systemd/system/multi-user.target.wants" "$rootfs_dir/etc/leanpi/firstboot.d"
ln -sf ../leanpi-firstboot.service "$rootfs_dir/etc/systemd/system/multi-user.target.wants/leanpi-firstboot.service"
install -Dm755 scripts/service-audit.sh "$rootfs_dir/usr/local/sbin/leanpi-service-audit"
install -Dm755 scripts/resource-baseline.sh "$rootfs_dir/usr/local/sbin/leanpi-resource-baseline"

if [[ $KERNEL_FAMILY == virt ]]; then bash scripts/install-virt-boot.sh "$BOARD_ID" "$rootfs_dir"; fi
if [[ $KERNEL_FAMILY == raspberrypi ]]; then bash scripts/install-raspi-boot.sh "$BOARD_ID" "$rootfs_dir"; fi

# Keep the shipped image lean. Run this after board-specific kernel/boot package
# installation, because those steps refresh APT indexes and download packages.
# The removed files are reproducible build-time state; apt update recreates them.
rm -rf "$rootfs_dir/var/lib/apt/lists/"* \
       "$rootfs_dir/var/cache/apt/"* \
       "$rootfs_dir/var/cache/debconf/"*-old \
       "$rootfs_dir/var/cache/man/"* \
       "$rootfs_dir/var/log/"*.log \
       "$rootfs_dir/var/log/apt/"*
mkdir -p "$rootfs_dir/var/lib/apt/lists/partial" "$rootfs_dir/var/cache/apt/archives/partial"
find "$rootfs_dir/usr/share/doc" -type f \( -name '*.gz' -o -name changelog.Debian -o -name changelog.Debian.gz \) -delete 2>/dev/null || true
# Debian kernel packages install modules for many unrelated ARM boards. Keep
# module metadata intact for now; report the largest directories so size
# optimization can be evidence-driven rather than deleting hardware support.
echo "LeanPi rootfs size diagnostics:"
du -x -B1 -d1 "$rootfs_dir/usr" "$rootfs_dir/lib" "$rootfs_dir/var" 2>/dev/null | sort -nr | head -n 20 || true
for dir in "$rootfs_dir/usr/share" "$rootfs_dir/var/cache"; do
  if [[ -d "$dir" ]]; then
    du -x -B1 -d1 "$dir" 2>/dev/null | sort -nr | head -n 20 || true
  fi
done
if [[ -d "$rootfs_dir/lib/modules" ]]; then
  du -x -B1 -d2 "$rootfs_dir/lib/modules" 2>/dev/null | sort -nr | head -n 20 || true
fi
loopdev=; mnt=; cleanup(){ set +e; [[ -n $mnt ]] && mountpoint -q "$mnt" && umount "$mnt"; [[ -n $mnt && -d $mnt ]] && rmdir "$mnt"; [[ -n $loopdev ]] && losetup -d "$loopdev"; }; trap cleanup EXIT
loopdev=$(losetup --find --show --partscan "$image_path"); mkfs.ext4 -F -L leanpi-root "${loopdev}p1" >/dev/null; mnt=$(mktemp -d); mount "${loopdev}p1" "$mnt"; rsync -aHAX --numeric-ids "$rootfs_dir/" "$mnt/"; sync; umount "$mnt"; rmdir "$mnt"; mnt=; losetup -d "$loopdev"; loopdev=
echo 'LeanPi M1.2 image assembly: PASS'; echo "Image: $image_path"; du -sh "$rootfs_dir"; sha256sum "$image_path" | tee "${image_path}.sha256"
