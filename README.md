# LeanPi

LeanPi is a Debian-based operating system for single-board computers with two priorities:

1. **Run well on old and weak boards.** ARMv6 and ARMv7 are first-class targets, not legacy afterthoughts.
2. **Stay extremely lean on larger boards.** Extra RAM and CPU should remain available to user workloads instead of being consumed by the base OS.

> Modern Linux for small and old boards.

## Design goals

- Debian as the base distribution, initially Debian 13 (Trixie).
- Headless-first and minimal by default.
- Old and resource-constrained hardware is a primary design target.
- 256 MiB RAM systems should be practical; lower-memory targets are evaluated where hardware and Debian support allow it.
- ARMv6/ARMv7 support is treated as first-class where the Debian ecosystem makes it feasible.
- ARM64, RISC-V and x86-64 are supported without adding unnecessary baseline overhead.
- Minimal number of background services and processes.
- Low idle memory use.
- Small root filesystem.
- Minimise unnecessary writes to SD cards and eMMC.
- Board support is separated from the common LeanPi userspace.
- Reproducible image builds.
- No telemetry by default.
- Avoid unnecessary LeanPi-specific kernel and U-Boot forks.
- Features are opt-in unless they are required for a functional base system.

A core rule is:

> A feature does not belong in LeanPi Base merely because modern hardware can afford it.

## Appliance principles

LeanPi is a **lean multi-appliance platform**: one small, reproducible base that can become many purpose-built appliances through profiles and recipes.

- **If LeanPi supports it, LeanPi supports it properly.** A profile is not considered first-class merely because it can install a package.
- First-class appliance profiles cover the full lifecycle where applicable: **install → configure → optimise → harden → validate → monitor → update → backup → restore → migrate → remove**.
- Profiles are scriptable, reproducible and non-interactive by design; interactive front ends are optional conveniences over the same automation interfaces.
- Profiles should be declarative and composable so one board can host one tightly focused appliance or several compatible roles.
- Defaults are hardware-aware. RAM, CPU, architecture, storage and board class should influence sensible resource settings instead of applying Pi 5-class defaults to a Pi Zero-class machine.
- Optimisation never justifies weakening security, correctness, data integrity or interoperability.
- Services remain opt-in. Supporting many appliances must not turn LeanPi Base into a large resident management stack.
- Prefer upstream software and standard Debian/systemd mechanisms. Create separate LeanPi/Ploos software projects when there is genuinely new technology to build, not merely to wrap an existing service.
- Every supported appliance category should be able to reach the same quality bar; no category is intentionally second-class.

A practical rule for new ideas is: **new service → LeanPi profile first; new implementation/technology → separate project when justified.**

## M0 reference target

The initial reference board is the **Orange Pi Zero / Zero LTS family**:

- Allwinner H2+/H3 family
- ARMv7 / armhf
- 256 or 512 MiB RAM
- U-Boot
- mainline/sunxi Linux where practical
- Debian 13 Trixie
- headless operation

This target is intentionally constrained enough to expose regressions in memory usage, process count, storage footprint and I/O behaviour.

## Initial resource budgets

M0 defines budgets as measurable engineering targets rather than marketing claims. The first working image will establish the baseline, after which budgets become regression gates.

Initial targets for the Orange Pi Zero LTS reference platform:

- idle RAM: **< 40 MiB** first target, with **< 32 MiB** as a later optimisation target
- root filesystem: **< 500 MiB** first target, then reduce further where it does not harm maintainability
- minimal enabled services
- measurable boot process count
- measurable persistent storage writes over time

See [docs/RESOURCE_BUDGET.md](docs/RESOURCE_BUDGET.md).

## Architecture

LeanPi is not a DietPi fork. DietPi is an inspiration and useful comparison point, but LeanPi is designed as an independent Debian-based system with its own builder and board support model.

High-level layout:

```text
Debian
  |
  +-- minimal bootstrap
  |
  +-- LeanPi base
  |    +-- minimal init/service set
  |    +-- networking
  |    +-- SSH
  |    +-- logging policy
  |    +-- storage/write policy
  |
  +-- board support
  |    +-- bootloader integration
  |    +-- kernel/DTB integration
  |    +-- board metadata
  |
  +-- optional profiles/software
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Roadmap

M0 establishes project principles, resource budgets, architecture, board policy and the initial builder skeleton.

The first functional milestone will produce a bootable Debian Trixie ARMv7 image for Orange Pi Zero LTS and measure it against the M0 budgets.

See [ROADMAP.md](ROADMAP.md).

## Status

**M0: in progress**

- [x] Project scope and priorities
- [x] Architecture baseline
- [x] Resource budget policy
- [x] Hardware support policy
- [x] Roadmap
- [x] Initial builder skeleton
- [ ] First Orange Pi Zero LTS image
- [ ] First measured resource baseline

## License

LeanPi project software is licensed under the MIT License unless a file or component states otherwise. Third-party components keep their upstream licenses.

See [LICENSE](LICENSE).
