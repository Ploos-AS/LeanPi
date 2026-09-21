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

## M3 — Profiles and software

Keep the base minimal while adding opt-in profiles:

- headless-server
- network-appliance
- IoT/MQTT
- monitoring-agent
- retro/BBS networking
- HAM/radio appliance

## M4 — Additional architectures

Apply the same lean-base and measurable-qualification principles to:

- riscv64
- amd64

ARM64 is no longer deferred to M4: it enters early through Raspberry Pi 3 and QEMU virt so 32/64-bit support evolves together.

## Long-term policy

Old boards are not removed simply because they are old. A target may be retired when required upstream components become unmaintainable, insecure, unavailable, or impossible to build reliably. Any retirement must document the technical reason.
