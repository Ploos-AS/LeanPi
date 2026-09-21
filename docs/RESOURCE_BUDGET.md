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

## Trade-offs

LeanPi does not optimise solely for the smallest possible number. Security, maintainability, data integrity and compatibility can justify additional resource use. Such trade-offs should be explicit and measurable.
