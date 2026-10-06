# LeanPi Resource Budget

LeanPi treats resource efficiency as a measurable engineering requirement.

## Reference platform

Initial measurements target Orange Pi Zero / Zero LTS with 256 or 512 MiB RAM, Debian 13 Trixie and a headless configuration.

## M0/M1 targets

These are first engineering targets, not guaranteed marketing claims.

- Idle RAM: under 40 MiB after first boot and stabilisation.
- Stretch target: under 32 MiB idle RAM.
- Root filesystem: under 500 MiB initially.
- Minimal enabled system services.
- Base-image regression gates: at most 14 enabled systemd units and at most 4 running services.
- Minimal idle process count.
- Persistent storage writes must be measurable and should be minimised.
- No unnecessary polling daemons.

## Measurement rules

Measurements should record:
- board/revision
- RAM size
- kernel version
- LeanPi commit
- Debian release
- uptime at measurement
- enabled services
- process count
- `MemTotal`, `MemAvailable`, and major tmpfs usage
- root filesystem used bytes
- relevant persistent write counters when available

Idle RAM should be measured after the machine has completed first boot and remained idle long enough for transient setup processes to finish.

## Regression policy

Once a stable M1 baseline exists, CI or qualification tooling should compare new builds against it. Material regressions require either:

1. optimisation before merge, or
2. a documented reason explaining why the extra resource use is justified.

Larger hardware does not relax the base budget automatically.

### Emulated qualification ceilings

The under-40-MiB idle-RAM target is a product target for the physical reference
platform, initially Orange Pi Zero / Zero LTS. Generic QEMU machines are also
measured with the same `MemTotal - MemAvailable` definition, but architecture
and generic-kernel reservations can materially change the result.

QEMU lanes therefore use explicit regression ceilings where needed. These
ceilings do not redefine or relax the physical reference-platform target:

- `orangepi-pc` QEMU: under 48 MiB (49,152 KiB). This is the emulated
  Orange Pi PC regression ceiling; it does not replace the under-40-MiB target
  for physical Orange Pi Zero / Zero LTS qualification.
- `raspi2b` QEMU: under 48 MiB (49,152 KiB), based on the QEMU Raspberry Pi 2
  machine baseline. Physical Raspberry Pi 2 measurements remain separate.
- `raspi3b-arm64` QEMU: under 128 MiB (131,072 KiB). QEMU's Raspberry Pi 3
  machine has substantially higher reported memory use than the generic ARM64
  virt machine; this ceiling is therefore only a regression guard for that
  emulator model, not a physical-board target.
- `virt-armhf`: under 40 MiB.
- `virt-arm64`: under 44 MiB (45,056 KiB), based on the Debian 13 generic
  ARM64 qualification baseline. The measured value remains visible in evidence
  and material increases must be investigated rather than silently absorbed.

In addition to the RAM ceilings above, M1.1 uses conservative root-filesystem
regression ceilings for QEMU images: under 320 MiB (335,544,320 bytes) for
ARMHF lanes and under 440 MiB (461,373,440 bytes) for ARM64 lanes. These are
CI bloat guards with headroom above the measured baselines; they do not replace
the under-500-MiB physical reference-platform target.

A QEMU ceiling is a CI regression guard for that emulated platform, not a
marketing claim or substitute for physical-board qualification.

The M1.1 base image also gates systemd configuration at no more than 14
persistent enabled units and 4 running services. These limits match the green
cross-machine QEMU baseline and are intended to catch accidental background
service growth. Process count remains evidence-only because it varies
materially with the emulated board and kernel.

## Trade-offs

LeanPi does not optimise solely for the smallest possible number. Security, maintainability, data integrity and compatibility can justify additional resource use. Such trade-offs should be explicit and measurable.
