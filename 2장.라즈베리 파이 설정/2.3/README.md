# Raspberry Pi 4 64-bit build scripts

These scripts are adapted for the study server checked on 2026-11-13:

- Raspberry Pi 4 Model B Rev 1.1 (BCM2711)
- Debian 13, AArch64
- Running kernel: `6.18.34+rpt-rpi-v8`

They use the Raspberry Pi kernel repository's `rpi-6.18.y` source branch,
`bcm2711_defconfig`, and the ARM64 `Image.gz` target. This is a learning build
from the Raspberry Pi kernel tree; it is not a rebuild of Debian's packaged
kernel.

## Prepare and build

From this directory on the Pi, install the build dependencies. Then fetch the
kernel source into a path without spaces. The kernel build system does not
support spaces in its source or output paths:

```sh
sudo apt update
sudo apt install build-essential bc bison flex libssl-dev
REPO_ROOT="$(git rev-parse --show-toplevel)"
git clone --depth=1 --branch rpi-6.18.y https://github.com/raspberrypi/linux.git "$REPO_ROOT/linux-source"
```

Then build the kernel image, modules, and device trees:

```sh
./build_rpi_kernel.sh
```

The script uses two parallel jobs by default. Override this with `JOBS=1` or
`JOBS=3` before the command if desired. Build output goes into
`$REPO_ROOT/kernel-build/out/`; the script does not install or activate the
kernel.

To generate a preprocessed source file, pass its kernel-tree target ending in
`.i`, for example:

```sh
./build_preprocess_rpi_kernel.sh kernel/sched/core.i
```

## Stage a test kernel

After a successful build, run:

```sh
sudo ./install_rpi_kernel_img.sh
```

This installs the custom modules and creates a matching initramfs, then stages
the kernel, device trees, overlays, command line, and initramfs under
`/boot/firmware/kernel-study/<kernel-release>/`. It does not overwrite the
default kernel or edit `config.txt`.

To opt in to the staged kernel, manually add the printed `os_prefix=.../` line
under `[all]` in `/boot/firmware/config.txt`, then reboot. Remove that line to
select the normal packaged kernel again. Keep SSH access or physical access to
the boot media available while trying a custom kernel.

These scripts do not change the original book's historical reference links;
they update its old 32-bit build example for this Pi 4 64-bit setup.
