#!/bin/bash
#
# Kernel build functions
#

build() {
    echo -e "\nINFO: Starting kernel build..."

    [ -f log.txt ] && rm log.txt
    
    # Setup ccache
    if [ "$USE_CCACHE" == "1" ]; then
        if command -v ccache &> /dev/null; then
            echo "INFO: Using ccache"
            export CC="ccache clang"
            export HOSTCC="ccache clang"
            export HOSTCXX="ccache clang++"
            ccache -M 10G &> /dev/null || true
        else
            echo "WARNING: ccache not found, building without it"
            export CC="clang"
        fi
    else
        export CC="clang"
    fi
    
    # Make flags
    MAKE_ARGS=(
        -j$(nproc --all)
        O="$OUTDIR"
        ARCH=arm64
        LLVM=1
        LLVM_IAS=1
        EXYNOS_SOC="$SOC"
        EXYNOS_SOC_DIR="."
        ROOT_DIR="$KDIR"
        KCFLAGS="-Wno-error=array-bounds"
        KBUILD_MODPOST_WARN=1
    )
    
    if [ "$DO_QUIET" == "1" ]; then
        MAKE_ARGS+=(KBUILD_VERBOSE=0)
    fi
    
    # Generate defconfig
    echo "INFO: Generating defconfig..."
    if ! make "${MAKE_ARGS[@]}" CC="$CC" "$DEFCONFIG" 2>&1 | tee -a log.txt; then
        echo -e "\nERROR: Defconfig generation failed!"
        echo "ERROR: Check log.txt for details"
        exit 1
    fi
    
    # Set LOCALVERSION
    VERSION_STR="\"-gts10fewifi-$KERNEL_VARIANT_SHORT\""
    scripts/config --file "$OUTDIR/.config" --set-val LOCALVERSION "$VERSION_STR"
    
    # Menuconfig if requested
    if [ "$DO_MENUCONFIG" == "1" ]; then
        if ! make "${MAKE_ARGS[@]}" CC="$CC" menuconfig 2>&1 | tee -a log.txt; then
            echo -e "\nERROR: Menuconfig failed!"
            exit 1
        fi
    fi
    
    # Build kernel, modules, and device trees
    echo "INFO: Building kernel, modules, and device trees..."
    if ! make "${MAKE_ARGS[@]}" CC="$CC" Image modules dtbs 2>&1 | tee -a log.txt; then
        echo -e "\nERROR: Kernel build failed!"
        echo "ERROR: Check log.txt for details"
        exit 1
    fi
    
    # Verify kernel image was created
    if [ ! -f "$OUTDIR/arch/arm64/boot/Image" ]; then
        echo -e "\nERROR: Kernel Image not found after build!"
        echo "ERROR: Build may have failed silently"
        exit 1
    fi
    
    echo "INFO: Kernel build completed successfully"
}

clean() {
    echo "INFO: Cleaning build artifacts..."
    make clean > /dev/null 2>&1 || true
    make mrproper > /dev/null 2>&1 || true
}
