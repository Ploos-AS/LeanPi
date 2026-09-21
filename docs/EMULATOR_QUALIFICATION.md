# Emulator qualification

LeanPi uses emulation as an early qualification layer, but emulator results do not replace physical-board qualification.

## QEMU targets

### Orange Pi PC / Allwinner H3

QEMU provides an `orangepi-pc` machine implementing an Allwinner H3 platform. This is close enough to the Orange Pi Zero / Zero LTS H2+/H3 family to test much of the LeanPi boot path:

- ARMv7 userspace and kernel
- U-Boot
- BootROM-style loading from an SD image
- UART/serial console
- SD/MMC
- Ethernet
- Linux userspace boot
- basic service and resource-regression tests

It is not an exact Orange Pi Zero model. A QEMU PASS therefore means that the generic H3/sunxi path is healthy, not that the Orange Pi Zero hardware is qualified.

Suggested smoke test once the LeanPi image contains U-Boot/kernel/DTB:

```sh
qemu-system-arm \
  -M orangepi-pc \
  -nic user \
  -nographic \
  -sd out/orangepi-pc/leanpi-orangepi-pc.img
```

A dedicated `orangepi-pc` board definition should be used for emulator qualification because its DTB and U-Boot defconfig differ from the physical Orange Pi Zero target.

### Generic ARM virt

A second CI target may use QEMU's `virt` machine. It is useful for qualifying architecture-independent LeanPi userspace, init, networking and package changes quickly, but it does not qualify sunxi/U-Boot board integration.

## Qualification levels

1. **Builder PASS** — metadata and image construction.
2. **QEMU virt PASS** — generic ARM/Linux userspace.
3. **QEMU Orange Pi PC PASS** — H3/sunxi boot path, serial, storage and networking.
4. **Physical Orange Pi Zero / Zero LTS PASS** — authoritative hardware qualification.

Only level 4 may promote the Orange Pi Zero / Zero LTS board from experimental hardware status.

## CI direction

Add headless QEMU boot tests with a timeout and serial-log assertions. CI should fail if the kernel panics, the root filesystem cannot mount, or a LeanPi boot-complete marker is not reached.
