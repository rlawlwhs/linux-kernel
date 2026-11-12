#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 || "$1" != *.i || "$1" == /* || "$1" == *..* ]]; then
    echo "Usage: $0 relative/path/to/source_file.i" >&2
    echo "Example: $0 kernel/sched/core.i" >&2
    exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
KERNEL_SRC="${KERNEL_SRC:-$SCRIPT_DIR/linux}"
OUTPUT="${OUTPUT:-$SCRIPT_DIR/out}"
BUILD_LOG="${BUILD_LOG:-$SCRIPT_DIR/rpi_preprocess_build_log.txt}"
PREPROCESS_TARGET="$1"
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

SOURCE_FILE="$KERNEL_SRC/${PREPROCESS_TARGET%.i}.c"
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Source file for target '$PREPROCESS_TARGET' was not found: $SOURCE_FILE" >&2
    exit 1
fi

mkdir -p "$OUTPUT"
cd "$KERNEL_SRC"

echo "Creating the Raspberry Pi 4 64-bit default configuration"
make O="$OUTPUT" ARCH=arm64 bcm2711_defconfig
scripts/config --file "$OUTPUT/.config" --set-str LOCALVERSION "$LOCALVERSION"
make O="$OUTPUT" ARCH=arm64 olddefconfig

echo "Generating preprocessed source: $PREPROCESS_TARGET"
make O="$OUTPUT" ARCH=arm64 "$PREPROCESS_TARGET" 2>&1 | tee "$BUILD_LOG"

printf '\nPreprocessing complete.\nOutput directory: %s\nBuild log: %s\n' "$OUTPUT" "$BUILD_LOG"
