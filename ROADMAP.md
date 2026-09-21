# LeanPi Roadmap

LeanPi prioritises old/resource-constrained hardware while treating both 32-bit and 64-bit systems as first-class engineering targets.

## M0 — Project foundation

- Define scope and design principles.
- Define architecture and board support separation.
- Define measurable resource budgets.
- Define hardware support/deprecation policy.
- Add initial builder skeleton.
- Select Orange Pi Zero / Zero LTS as first reference target.

Exit criteria:
- Repository structure is established.
- Builder can validate host prerequisites and target metadata.
- Orange Pi Zero LTS target metadata is present.
- Resource metrics and support policy docs exist.

## M1 — First bootable image

Goal: Produce a reproducible Debian 13 Trixie ARMv7 image for Orange Pi Zero / Zero LTS.

- Bootstrap minimal armhf rootfs.
- Install kernel, DTB and U-Boot integration.
- Configure serial console and Ethernet.
- Provide first-boot hostname/password/key setup.
- Add minimal SSH service.
- Add image partitioning and filesystem creation.
- Add QEMU H3/sunxi qualification before hardware qualification.
- Boot and qualify on physical Orange Pi Zero LTS.
- Capture first resource baseline.

## M1.1 — Base optimisation

- Reduce idle RAM.
- Reduce enabled units and process count.
- Reduce image/rootfs size.
- Reduce persistent writes.
- Establish automated regression reporting.

## M2 — Multi-architecture hardware and qualification framework

- Formal board metadata schema.
- Family-level BSP reuse.
- Architecture-aware bootstrap and package handling.
- Board qualification records.
- QEMU qualification matrix.
- Keep 32-bit and 64-bit lanes independently testable.
- Prevent incompatible architecture packages from entering images.

First-class early targets:
- Orange Pi Zero / Zero LTS — ARMv7/armhf, physical reference.
- QEMU Orange Pi PC — ARMv7/armhf sunxi CI proxy.
- Raspberry Pi Zero / Zero W and Pi 1 — ARMv6 legacy/armel compatibility lane.
- Raspberry Pi 2 — ARMv7/armhf.
- Raspberry Pi 3 — **both armhf (32-bit) and arm64 (64-bit)**.
- QEMU virt — armhf and arm64 generic CI.
- selected older NanoPi/sunxi boards.

For Raspberry Pi 3, measure the 32-bit and 64-bit profiles against the same resource metrics so architecture overhead is visible rather than assumed.

## Design doctrine: small-board first

LeanPi may learn from mature minimal-SBC distributions such as DietPi, but implements its own tooling and policy. Every feature must justify its RAM, storage, CPU, write-I/O and maintenance cost.

- Base image stays headless, minimal and useful without a management daemon.
- No always-running LeanPi daemon unless a feature fundamentally requires one.
- Prefer shell/static or already-present Debian tooling over new runtimes and dependency stacks.
- Interactive tools must also expose non-interactive CLI operation.
- Optional features belong in recipes/profiles, not LeanPi Base.
- Prefer on-demand execution to polling and resident background processes.
- Avoid duplicate functionality already provided well by Debian/systemd.
- Logging defaults must minimise persistent writes while preserving useful diagnostics.
- Network services are opt-in; no telemetry, discovery or cloud dependency by default.
- Features are measured on the weakest supported boards first. Faster boards do not define the base budget.
- A new base dependency requires measured justification and a documented removal/rollback path.
- Optimisation must not trade away security, data integrity or reproducibility.

### Feature admission gate

Before a feature enters LeanPi Base it must answer: can this be optional; can it run on demand; can an existing base tool do it; what does it add to image size, idle RAM, process/service count and persistent writes; and does it remain practical on ARMv6/ARMv7-class hardware? CI/qualification should capture these costs where measurable.

## M3 — LeanPi Tools, profiles and software

Keep the base minimal. Administration features must remain lightweight and opt-in where practical, and every interactive tool should also support non-interactive automation.

Core LeanPi Tools:
- `leanpi` / `leanpi-launcher` — lightweight launcher for administration tools.
- `leanpi-config` — network, locale, hostname, hardware and system configuration.
- `leanpi-software` — recipe-driven software installation and removal.
- `leanpi-services` — inspect, enable, disable and manage services.
- `leanpi-log` — selectable volatile, hybrid and persistent logging modes.

Initial opt-in profiles:
- headless-server
- network-appliance
- IoT/MQTT
- monitoring-agent
- retro/BBS networking
- HAM/radio appliance

Design requirements:
- LeanPi Base must not grow merely because larger boards can afford extra features.
- Tools should use standard Debian/systemd facilities rather than replacing them.
- CLI/non-interactive operation is first-class so configuration can be reproduced in CI and provisioning.
- Small ARMv6/ARMv7 systems remain a resource-budget gate for core tools.

## M4 — System management and automation

- `leanpi-backup` — system backup/restore with configurable retention and destinations.
- `leanpi-drive` — storage, filesystem, swap and network-mount management.
- `leanpi-update` — controlled LeanPi/system update workflow.
- `leanpi-firstboot` — reproducible unattended first-boot provisioning.
- `leanpi-benchmark` — lightweight resource and performance measurements.
- Expand the recipe catalogue while keeping software outside LeanPi Base by default.

## M5 — Additional architectures

Apply the same lean-base and measurable-qualification principles to:

- riscv64
- amd64

ARM64 is no longer deferred to the additional-architecture milestone: it enters early through Raspberry Pi 3 and QEMU virt so 32/64-bit support evolves together.

## M4 — Additional architectures

Apply the same lean-base and measurable-qualification principles to:

- riscv64
- amd64



## Long-term policy

Old boards are not removed simply because they are old. A target may be retired when required upstream components become unmaintainable, insecure, unavailable, or impossible to build reliably. Any retirement must document the technical reason.
