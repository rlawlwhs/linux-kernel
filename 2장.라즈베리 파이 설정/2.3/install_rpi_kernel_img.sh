#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID != 0 )); then
    echo "Run this script with sudo to install the study kernel's modules and initramfs." >&2
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
BUILD_ROOT="${BUILD_ROOT:-$PROJECT_ROOT/kernel-build}"
KERNEL_SRC="${KERNEL_SRC:-$PROJECT_ROOT/linux-source}"
OUTPUT="${OUTPUT:-$BUILD_ROOT/out}"
BOOT_DIR=/boot/firmware
ARCH=arm64

if [[ ! -f "$KERNEL_SRC/Makefile" || ! -f "$OUTPUT/.config" ]]; then
    echo "Kernel source or build configuration is missing. Run build_rpi_kernel.sh first." >&2
    exit 1
fi

case "$KERNEL_SRC$OUTPUT" in
    *" "*)
        echo "Kbuild does not support spaces in the kernel source or output path." >&2
        echo "Move them to paths without spaces or set KERNEL_SRC and OUTPUT explicitly." >&2
        exit 1
        ;;
esac

if [[ ! -f "$BOOT_DIR/config.txt" || ! -f "$BOOT_DIR/cmdline.txt" ]]; then
    echo "Expected Raspberry Pi boot files under $BOOT_DIR; refusing to install." >&2
    exit 1
fi

if ! command -v update-initramfs >/dev/null 2>&1; then
    echo "update-initramfs is required to prepare this Debian system's initramfs." >&2
    exit 1
fi

KERNEL_IMAGE="$OUTPUT/arch/arm64/boot/Image.gz"
DTB_DIR="$OUTPUT/arch/arm64/boot/dts/broadcom"
OVERLAY_DIR="$OUTPUT/arch/arm64/boot/dts/overlays"
if [[ ! -f "$KERNEL_IMAGE" || ! -d "$DTB_DIR" || ! -f "$OVERLAY_DIR/README" ]]; then
    echo "Expected ARM64 Image.gz, Broadcom DTBs, or overlay files are missing from $OUTPUT." >&2
    echo "Run build_rpi_kernel.sh to build the kernel, modules, and device trees first." >&2
    exit 1
fi

KERNEL_RELEASE="$(make -s -C "$KERNEL_SRC" O="$OUTPUT" ARCH="$ARCH" kernelrelease)"
BOOT_STAGE="$BOOT_DIR/kernel-study/$KERNEL_RELEASE"

echo "Installing modules under /lib/modules/$KERNEL_RELEASE"
make -C "$KERNEL_SRC" O="$OUTPUT" ARCH="$ARCH" modules_install
depmod -a "$KERNEL_RELEASE"

if [[ -e "/boot/initrd.img-$KERNEL_RELEASE" ]]; then
    update-initramfs -u -k "$KERNEL_RELEASE"
else
    update-initramfs -c -k "$KERNEL_RELEASE"
fi

echo "Staging boot files under $BOOT_STAGE (the active kernel and config.txt will not be changed)"
install -d "$BOOT_STAGE/overlays"
install -m 0644 "$KERNEL_IMAGE" "$BOOT_STAGE/kernel8.img"
find "$DTB_DIR" -maxdepth 1 -type f -name '*.dtb' -exec install -m 0644 {} "$BOOT_STAGE/" \;
cp -a "$OVERLAY_DIR/." "$BOOT_STAGE/overlays/"
install -m 0644 "$BOOT_DIR/cmdline.txt" "$BOOT_STAGE/cmdline.txt"
install -m 0644 "/boot/initrd.img-$KERNEL_RELEASE" "$BOOT_STAGE/initramfs8"

cat <<EOF

Study kernel staged without changing the active boot selection.
To test it, add this line to $BOOT_DIR/config.txt under [all]:
  os_prefix=kernel-study/$KERNEL_RELEASE/

The existing kernel remains in place. To return to it, remove the os_prefix line.
EOF
