#!/bin/bash
#
# Build script for gts10fewifi kernel (Exynos s5e8855)
# Based on FloppyKernel s5e8825 (Floppy1280) script.
# Copyright (C) 2025 Flopster101
#
# ACK branch: android15-6.6
#

set -e

# Trap termination signals
trap 'echo -e "\n\nERROR: Build interrupted by user (Ctrl+C)\n"; exit 130' INT TERM

## Variables
DEFAULT_DEFCONFIG="gts10fewifi_defconfig"
SECONDS=0
DATE="$(date '+%Y%m%d-%H%M')"

# Workspace
if [ -z "$WP" ]; then
    echo -e "\nERROR: WP (workspace) variable not set\n"
    echo "Set it, or run the do_build.sh wrapper"
    exit 1
fi

# Kernel directory
KDIR="$(readlink -f .)"

if [ ! -d "$KDIR/drivers" ] || [ ! -f "$KDIR/Makefile" ]; then
    echo -e "\nERROR: Kernel source not found at $KDIR\n"
    echo "WP is set to: $WP"
    exit 1
fi

cd "$KDIR"
export KDIR

export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-builder}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-buildhost}"

## Directories
OUTDIR="$KDIR/out"
IMAGES_DIR="$KDIR/out_images"

## Customizable vars
KERNEL_VER="v1.0a" # placeholder
DEVICE="Galaxy Tab S10 FE WiFi"
CODENAME="gts10fewifi"
SOC="s5e8855"

## Kernel variant
# Default to Vanilla
KERNEL_VARIANT="Vanilla"
KERNEL_VARIANT_SHORT="V"

## Toggles
USE_CCACHE=1
DO_CLEAN=0
DO_MENUCONFIG=0
DO_QUIET=0
DO_VENDOR_BOOT=1  # Default: build vendor_boot
DO_GKI_ONLY=0
DEFCONFIG=$DEFAULT_DEFCONFIG

## Parse arguments
for arg in "$@"; do
    # Check for long options first
    if [[ "$arg" == "--gki" ]]; then
        echo "INFO: GKI-only build (no vendor_boot)"
        DO_VENDOR_BOOT=0
        DO_GKI_ONLY=1
        continue
    fi
    
    # Parse single-letter flags
    if [[ "$arg" == *m* ]]; then
        echo "INFO: menuconfig argument passed"
        DO_MENUCONFIG=1
    fi
    if [[ "$arg" == *c* ]]; then
        echo "INFO: clean argument passed"
        DO_CLEAN=1
    fi
    if [[ "$arg" == *q* ]]; then
        echo "INFO: Quiet mode"
        DO_QUIET=1
    fi
done

echo -e "\nINFO: Build info:
- Device: $DEVICE ($CODENAME)
- SoC: $SOC
- Variant: $KERNEL_VARIANT
- Kernel version: $KERNEL_VER
- Linux version: $(make kernelversion 2>/dev/null)
- Defconfig: $DEFCONFIG
- Toolchain: ${CLANG_TYPE:-aosp-r510928}
- Build type: $([ "$DO_GKI_ONLY" -eq 1 ] && echo "GKI-only" || echo "Full (boot + vendor_boot)")
- Build date: $DATE
- Clean build: $([ "$DO_CLEAN" -eq 1 ] && echo "Yes" || echo "No")
"

# Source subscripts
SCRIPT_DIR="$KDIR/kernel_build/scripts"
source "$SCRIPT_DIR/tc.sh"
source "$SCRIPT_DIR/build.sh"
source "$SCRIPT_DIR/images.sh"
source "$SCRIPT_DIR/pack.sh"

## Main execution
if [ "$DO_CLEAN" == "1" ]; then
    clean
fi

build
package_images
build_boot_image
build_vendor_boot
create_odin_tar

echo -e "\nINFO: Build completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!"
echo "INFO: Output directory: $IMAGES_DIR"
if [ -n "$TAR_NAME" ] && [ -f "$TAR_NAME" ]; then
    echo "INFO: Odin package: $TAR_NAME"
fi
