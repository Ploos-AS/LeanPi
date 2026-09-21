# LeanPi Hardware Support Policy

LeanPi exists first to keep useful older SBCs viable, while remaining efficient on newer systems.

## Support tiers

### Tier 1 — Qualified

A Tier 1 board has:
- a maintained target definition
- reproducible image generation
- successful physical boot testing
- working console/network/storage relevant to the board
- recorded resource measurements
- a documented qualification result for releases

### Tier 2 — Build tested

A Tier 2 board has:
- maintained target metadata
- successful image generation
- structural image checks
- no recent physical qualification requirement

### Tier 3 — Experimental

An experimental target may build or partially boot but lacks complete qualification.

## Old hardware policy

Age alone is not a reason to remove a target.

A board may remain supported as long as the required bootloader, kernel, Debian userspace and build toolchain can be maintained safely and reliably.

A target may be retired when one or more of these conditions applies:
- essential upstream support disappears and carrying it becomes unreasonable
- required software can no longer be maintained securely
- the target cannot be built reproducibly with a supported toolchain
- hardware cannot be obtained or tested sufficiently to maintain confidence
- maintenance cost becomes disproportionate to the available technical path

Any retirement must document the technical reason and, where possible, the last usable LeanPi release.

## Architecture policy

Priority order is:

1. old/resource-constrained ARM hardware
2. efficient operation on newer hardware

Expected architecture families include:
- ARMv6 where a viable Debian/userspace path exists
- ARMv7 / armhf
- arm64
- riscv64
- amd64

LeanPi does not classify ARMv6/ARMv7 as second-class solely because newer hardware exists.

## Board metadata

Each target should eventually declare:
- stable LeanPi board ID
- display name
- architecture
- SoC and family
- RAM variants where relevant
- bootloader strategy
- kernel strategy
- DTB
- serial console
- primary storage
- network capabilities
- support tier
- qualification notes

## First reference target

`orangepi-zero-lts` is the first reference target because its ARMv7 CPU and 256/512 MiB memory make it a useful constraint for LeanPi's primary mission.
