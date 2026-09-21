# LeanPi Architecture

LeanPi is an independent Debian-based SBC operating system. It is inspired by projects such as DietPi, Armbian and minimal Debian installations, but it is not a fork of DietPi.

## Priorities

1. Old and weak boards must remain practical targets.
2. Larger boards should benefit from the same lean base rather than carrying additional mandatory overhead.

## Layering

```text
Debian repositories
        |
        v
Bootstrap layer
        |
        v
LeanPi common base
        |
        +---- Board Support Package metadata/integration
        |
        +---- Optional profiles/software
        |
        v
Bootable image
```

### Bootstrap layer

Responsibilities:
- create a minimal Debian root filesystem
- select architecture and release
- install only required base packages
- prepare chroot/emulation when required

The initial implementation is expected to use `mmdebstrap` where practical.

### Common base

The common base should contain only what is required for a useful headless system. Candidates include:
- init/service manager
- package management
- basic networking
- SSH access
- time synchronisation where justified
- minimal logging
- LeanPi configuration/state metadata

Every always-on service must have a documented reason to exist.

### Board support

Board-specific details must not leak unnecessarily into the common userspace. Board metadata should describe at least:
- board ID/name
- architecture
- SoC/family
- bootloader integration
- kernel package/source strategy
- DTB
- console
- storage assumptions
- network interfaces/capabilities

Family-level reuse is preferred over copy/paste board scripts.

### Optional profiles

Profiles are additive and must not redefine the base system. A profile may install packages, enable services and add configuration for a particular role, while remaining removable where practical.

## Init system

M0 assumes Debian systemd because it offers the lowest integration risk with Debian packages and hardware support. LeanPi will optimise the enabled unit set rather than replace the init system prematurely.

Alternative init systems may be evaluated later, but only against measured benefits and maintenance cost.

## SSH

A lightweight SSH server such as Dropbear is a candidate default for low-memory targets. OpenSSH remains an important compatibility option. The final default is decided by measured footprint, security maintenance, interoperability and first-boot requirements.

## Logging and temporary data

LeanPi aims to reduce persistent writes, especially on SD-card systems. RAM-backed volatile data may be used where appropriate, but reliable diagnostics and explicit persistence options must remain available.

## Kernel and bootloader policy

LeanPi should prefer maintained upstream or established distribution/vendor packages over permanent project-specific forks.

A LeanPi kernel/U-Boot fork is justified only when a required fix cannot reasonably be carried through upstream or an established BSP source. Such exceptions must be documented.

## Reproducibility

An image build must record at least:
- LeanPi commit
- Debian release
- architecture
- board target
- package versions or repository snapshot information where practical
- kernel and bootloader versions
- build timestamp
- generated image checksum

## Build host

The builder should be runnable on a normal Linux host and should make cross-architecture dependencies explicit. Containerised/reproducible build environments are a later goal, not a reason to delay the first small working builder.
