#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
KERNEL_SRC="${KERNEL_SRC:-$SCRIPT_DIR/linux}"
OUTPUT="${OUTPUT:-$SCRIPT_DIR/out}"
BUILD_LOG="${BUILD_LOG:-$SCRIPT_DIR/rpi_build_log.txt}"
JOBS="${JOBS:-2}"
ARCH=arm64
KERNEL=kernel8
CONFIG=bcm2711_defconfig
LOCALVERSION=-v8-study

if [[ ! -f "$KERNEL_SRC/Makefile" ]]; then
    cat >&2 <<EOF
Linux kernel source was not found at:
  $KERNEL_SRC

From this directory, get the Raspberry Pi 6.18 source with:
  git clone --depth=1 --branch rpi-6.18.y https://github.com/raspberrypi/linux.git linux
EOF
    exit 1
fi

if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
    echo "JOBS must be a positive integer (current value: $JOBS)" >&2
    exit 2
fi

for tool in make gcc bc bison flex; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required build tool not found: $tool" >&2
        echo "On Debian, install build dependencies with: sudo apt install build-essential bc bison flex libssl-dev" >&2
        exit 1
    fi
done

mkdir -p "$OUTPUT"
cd "$KERNEL_SRC"

echo "Source:       $KERNEL_SRC"
echo "Output:       $OUTPUT"
echo "Architecture: $ARCH"
echo "Kernel image: $KERNEL.img"
echo "Config:       $CONFIG"
echo "Parallel jobs: $JOBS"

echo "Creating the Raspberry Pi 4 64-bit default configuration"
make O="$OUTPUT" ARCH="$ARCH" "$CONFIG"

# Keep the study kernel's module directory separate from the installed kernel.
scripts/config --file "$OUTPUT/.config" --set-str LOCALVERSION "$LOCALVERSION"
make O="$OUTPUT" ARCH="$ARCH" olddefconfig

echo "Building the compressed kernel image, modules, and device trees"
make O="$OUTPUT" ARCH="$ARCH" -j"$JOBS" Image.gz modules dtbs 2>&1 | tee "$BUILD_LOG"

printf '\nBuild complete.\nKernel release: '
make -s O="$OUTPUT" ARCH="$ARCH" kernelrelease
printf 'Kernel image: %s\n' "$OUTPUT/arch/arm64/boot/Image.gz"
printf 'Build log:    %s\n' "$BUILD_LOG"
