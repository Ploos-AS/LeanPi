# Emulator qualification

LeanPi uses emulation as an early qualification layer, but emulator results do not replace physical-board qualification.

## Initial QEMU matrix

| Machine | CPU generation | LeanPi track | Purpose |
| --- | --- | --- | --- |
| `virt` | generic | armhf + arm64 | architecture-independent userspace/CI |
| `orangepi-pc` | Cortex-A7 / ARMv7 | armhf | H3/sunxi boot path |
| `raspi0` | ARM1176JZF-S / ARMv6 | armel compatibility | Pi Zero/Pi 1 legacy qualification |
| `raspi2b` | Cortex-A7 / ARMv7 | armhf | Raspberry Pi 2 / 32-bit |
| `raspi3b` | Cortex-A53 / ARMv8 | armhf + arm64 | Raspberry Pi 3 32/64-bit comparison |

QEMU also provides `raspi1ap`, `raspi3ap` and `raspi4b`; these are secondary targets initially.

## Orange Pi PC / Allwinner H3

`orangepi-pc` is close enough to the Orange Pi Zero / Zero LTS H2+/H3 family to exercise much of the LeanPi boot path: ARMv7, U-Boot, SD/MMC, UART, Ethernet, Linux userspace and regression tests. It is not an exact Orange Pi Zero model, so its PASS never substitutes for physical Zero/LTS qualification.

Use a dedicated `orangepi-pc` board definition because its DTB and U-Boot configuration differ from the physical Orange Pi Zero target.

## Raspberry Pi

### Pi Zero / Pi 1

QEMU `raspi0` models the ARM1176JZF-S generation. Debian armhf has an ARMv7 baseline and therefore cannot be used for this CPU. Debian 13 Trixie armel is a legacy/upgrade-only architecture, but its kernel support explicitly includes Raspberry Pi 1, Zero and Zero W. LeanPi therefore tracks this as an **armel compatibility/legacy lane**, not as normal armhf.

This lane must be isolated from the normal armhf builder so an ARMv7 package can never accidentally enter an ARMv6 image.

### Pi 2

`raspi2b` provides a Raspberry Pi ARMv7 target and belongs in the normal LeanPi armhf qualification lane.

### Pi 3: mandatory 32/64-bit target

`raspi3b` is an early first-class LeanPi target. Qualify it in two configurations:

- **32-bit:** armhf userspace/kernel path.
- **64-bit:** arm64 userspace/kernel path.

Keep the profiles comparable and record idle RAM, rootfs/image size, enabled services, process count and persistent writes. This gives LeanPi a controlled measurement of the cost/benefit of 32-bit versus 64-bit on the same board generation.

## Generic ARM virt

Use QEMU `virt` for fast architecture-independent CI. Maintain both armhf and arm64 variants. A virt PASS validates LeanPi userspace/init/networking but not Raspberry Pi or sunxi board integration.

## Qualification levels

1. **Builder PASS** — metadata and image construction.
2. **QEMU virt PASS** — generic architecture/userspace.
3. **QEMU board PASS** — board-family boot path and emulated devices.
4. **Physical board PASS** — authoritative hardware qualification.

Only physical qualification may promote a physical board to fully qualified status.

## CI gates

Headless QEMU jobs should have a timeout and serial-log assertions. Fail on kernel panic, failure to mount root, emergency mode, or failure to reach a LeanPi boot-complete marker.

The initial automated matrix is:

```text
virt-armhf
virt-arm64
orangepi-pc-armhf
raspi0-armel
raspi2b-armhf
raspi3b-armhf
raspi3b-arm64
```

Not every lane needs to become green at the same milestone. In particular, `raspi0-armel` is constrained by Debian 13's legacy armel status and must report that limitation explicitly rather than weakening the normal armhf baseline.


## Qualification records

A QEMU target is not considered qualified merely because an image builds or QEMU starts. A recorded **QEMU board PASS** requires the serial log to contain `LEANPI_BOOT_COMPLETE` and no fatal boot signature.

CI archives an evidence bundle for each qualification attempt. For `orangepi-pc` it contains:

- the complete serial log;
- the LeanPi commit SHA and GitHub Actions run/attempt IDs;
- QEMU version and machine name;
- architecture;
- SHA-256 of the tested image.

The evidence artifact is the authoritative record for an individual CI run. Repository documentation may summarize a PASS only after that evidence exists. Failed or incomplete runs must not be promoted to PASS.
