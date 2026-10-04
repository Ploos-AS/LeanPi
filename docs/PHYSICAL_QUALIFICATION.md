# Physical hardware qualification

Physical qualification is required before a board can become LeanPi Tier 1. Emulator results are useful regression evidence, but they do not replace a real board.

## Orange Pi Zero / Zero LTS reference procedure

1. Build the current image with `sudo ./build.sh orangepi-zero-lts`.
2. Verify the generated SHA-256 file before writing the image.
3. Write the image to a dedicated microSD card and boot an Orange Pi Zero or Zero LTS.
4. Confirm the U-Boot/kernel boot log on the 3.3 V UART serial console.
5. Confirm Ethernet obtains the expected link/configuration and that SSH is usable.
6. On the board, from a checkout of the exact LeanPi commit used to build the image, run:

   ```sh
   sudo scripts/hardware-qualification.sh
   ```

7. Preserve `leanpi-hardware-qualification.txt` together with the image SHA-256, board model/RAM size, LeanPi commit SHA and any serial boot log.

The capture script records architecture, kernel, serial-device presence, network interface/state, root storage/filesystem and the standard LeanPi resource baseline. It also applies the normal physical resource gate: idle RAM below 40 MiB and root filesystem below 500 MiB unless the qualification invocation explicitly documents another approved policy.

## Tier 1 acceptance

The reference board is ready for Tier 1 only when the evidence shows:

- successful physical boot from the generated image;
- usable serial console;
- usable Ethernet and SSH;
- working root storage;
- ARMv7/armhf userspace as expected;
- resource budget PASS;
- evidence tied to the exact image checksum and source commit.

Do not promote a board merely because the QEMU proxy is green. The board metadata remains experimental until physical evidence is reviewed and committed or attached to the corresponding release.
