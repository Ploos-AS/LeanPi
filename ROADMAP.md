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

### Multi-appliance profile roadmap

LeanPi should grow a broad, quality-gated appliance catalogue. IRC, Mystic BBS, honeypots, Prometheus/monitoring and Home Assistant/IoT are important early showcase areas, but the goal is for **every supported profile to shine** rather than creating privileged and second-class categories.

Planned profile families include:
- **Communication:** IRCd, IRC bouncers, IRC bots, Mystic BBS, FidoNet, Gopher and related communication services.
- **Network infrastructure:** DNS resolver/authoritative DNS, NTP, DHCP, VPN/Headscale, reverse proxy and network utilities.
- **Security:** SSH/web/multi-service honeypots, security sensors and defensive monitoring, with isolation and safe defaults.
- **Monitoring/observability:** Prometheus nodes/exporters, network probes, syslog collectors, SNMP monitoring and lightweight dashboards where hardware permits.
- **Home automation/IoT:** MQTT, Home Assistant satellites/edge roles, Bluetooth proxy, Zigbee/Thread gateways, sensor gateways and Node-RED-class workflows where appropriate.
- **Servers:** lightweight web/file/Git services and game-server profiles such as Minecraft, sized to hardware capability.
- **Retro:** BBS gateways, serial↔TCP services and Amiga/Atari/C64/retro-network support.
- **HAM/radio:** lightweight radio and network-service roles suitable for supported SBCs.

Profiles should be declarative and composable. The roadmap should support workflows conceptually equivalent to `leanpi enable <profile>` / `leanpi apply <profile-set>`, without requiring a permanently running LeanPi management daemon.

For first-class profiles, progressively add common lifecycle capabilities where relevant:
- install and remove
- reproducible configuration
- board/resource-aware optimisation
- hardening and firewall integration
- `doctor`/health validation
- metrics/monitoring integration
- controlled update
- backup and restore
- migration/export
- automated qualification tests

Longer-term: add an **Appliance Builder** that can combine target-board metadata and selected profiles to produce a reproducible, minimal image ready to flash. This must reuse the same profile/recipe definitions used for normal provisioning rather than creating a second configuration system.

Design requirements:
- LeanPi Base must not grow merely because larger boards can afford extra features.
- Tools should use standard Debian/systemd facilities rather than replacing them.
- CLI/non-interactive operation is first-class so configuration can be reproduced in CI and provisioning.
- Small ARMv6/ARMv7 systems remain a resource-budget gate for core tools.

## M4 — System management and automation

- `leanpi-backup` — system backup/restore with configurable retention and destinations.
- `leanpi-drive` — storage, filesystem, swap and network-mount management.
- `leanpi-update` — controlled LeanPi/system update workflow.
- `leanpi-firstboot` — reproducible unattended first-boot provisioning. **Implemented early:** one-shot hook runner, completion marker and systemd integration are already part of the base image; M4 extends this into richer provisioning workflows.
- `leanpi-benchmark` — lightweight resource and performance measurements.
- Expand the recipe catalogue while keeping software outside LeanPi Base by default.

## M5 — Additional architectures

Apply the same lean-base and measurable-qualification principles to:

- **legacy x86 / i386** — experimental low-end lane, with Data Evolution decTOP / AMD Geode as the physical reference target. Debian 13 no longer provides an installable i386 system/kernel and its remaining i386 userland requires SSE2, so Geode qualification starts from Debian 12 Bookworm rather than pretending Trixie is supported.
- riscv64
- amd64

The legacy-x86 lane is deliberately allowed to use an older Debian base while it remains security-maintained; LeanPi tooling and resource policy should stay common across releases. Promotion beyond experimental requires reproducible image builds, a maintained kernel/userspace path, physical decTOP qualification and documented security lifecycle.

ARM64 is no longer deferred to the additional-architecture milestone: it enters early through Raspberry Pi 3 and QEMU virt so 32/64-bit support evolves together.

## Long-term policy

Old boards are not removed simply because they are old. A target may be retired when required upstream components become unmaintainable, insecure, unavailable, or impossible to build reliably. Any retirement must document the technical reason.
