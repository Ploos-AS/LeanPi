# LeanPi Roadmap

LeanPi prioritises support for old/resource-constrained boards first, then efficiency on larger systems.

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
- Resource metrics and support policy are documented.

## M1 — First bootable image

Goal: Produce a reproducible Debian 13 Trixie ARMv7 image for Orange Pi Zero / Zero LTS.

- Bootstrap minimal armhf rootfs.
- Install kernel, DTB and U-Boot integration.
- Configure serial console and Ethernet.
- Provide first-boot hostname/password/key setup.
- Add minimal SSH service.
- Add image partitioning and filesystem creation.
- Boot and qualify on physical Orange Pi Zero LTS hardware.
- Capture first resource baseline.

## M1.1 — Base optimisation

- Reduce idle RAM.
- Reduce enabled units and process count.
- Reduce image/rootfs size.
- Reduce persistent writes.
- Establish automated regression reporting for metrics.

## M2 — Hardware framework

- Formal board metadata schema.
- Family-level BSP reuse.
- Additional old ARM targets.
- Architecture-aware package/bootstrap handling.
- Board qualification records.

Candidate early targets:
- Orange Pi Zero / Zero LTS
- Raspberry Pi 1
- Raspberry Pi Zero / Zero W
- selected older NanoPi/sunxi boards

## M3 — Profiles and software

Keep the base minimal while adding opt-in profiles, for example:

- headless-server
- network-appliance
- IoT/MQTT
- monitoring-agent
- retro/BBS networking
- HAM/radio appliance

## M4 — Larger architectures

Apply the same lean base principles to:

- arm64
- riscv64
- amd64

Larger boards are not an excuse for a larger mandatory base system.

## Long-term policy

Old boards are not removed simply because they are old. A supported target may be retired when required upstream components become unmaintainable, insecure, unavailable, or impossible to build reliably. Any retirement must be documented with the technical reason.
