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
- `virt-armhf`: under 40 MiB.
- `virt-arm64`: under 44 MiB (45,056 KiB), based on the Debian 13 generic
  ARM64 qualification baseline. The measured value remains visible in evidence
  and material increases must be investigated rather than silently absorbed.

A QEMU ceiling is a CI regression guard for that emulated platform, not a
marketing claim or substitute for physical-board qualification.

## Trade-offs

LeanPi does not optimise solely for the smallest possible number. Security, maintainability, data integrity and compatibility can justify additional resource use. Such trade-offs should be explicit and measurable.
