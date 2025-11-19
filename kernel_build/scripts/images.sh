#!/bin/bash
#
# Image packaging functions
#

package_images() {
    echo -e "\nINFO: Packaging kernel images..."
    
    mkdir -p "$IMAGES_DIR"
    
    # Copy kernel image
    if [ -f "$OUTDIR/arch/arm64/boot/Image" ]; then
        cp "$OUTDIR/arch/arm64/boot/Image" "$IMAGES_DIR/"
        echo "INFO: Copied Image"
    fi
    
    # Build DTB/DTBO
    export OUT_DIR="$OUTDIR"
    "$KDIR/kernel_build/scripts/dtb.sh"
    
    if [ -f "$OUTDIR/dtb/s5e8855.dtb" ]; then
        cp "$OUTDIR/dtb/s5e8855.dtb" "$IMAGES_DIR/"
        echo "INFO: Copied s5e8855.dtb"
    fi
    
    if [ -f "$OUTDIR/dtbo/dtbo.img" ]; then
        cp "$OUTDIR/dtbo/dtbo.img" "$IMAGES_DIR/"
        echo "INFO: Copied dtbo.img"
    fi

    # Copy modules
    if [ -d "$OUTDIR" ]; then
        echo "INFO: Installing modules..."
        # Silence INSTALL/STRIP spam but keep depmod warnings
        make -j$(nproc --all) O="$OUTDIR" ARCH=arm64 \
            INSTALL_MOD_PATH="$IMAGES_DIR/modules" \
            INSTALL_MOD_STRIP=1 \
            modules_install 2>&1 | grep -E "WARNING:|ERROR:|DEPMOD" || true
    fi
    
    # Copy config
    cp "$OUTDIR/.config" "$IMAGES_DIR/config"
    
    echo "INFO: Build artifacts saved to: $IMAGES_DIR"
}

build_boot_image() {
    local MKBOOTIMG="$HOME/Escritorio/TOOLS/mkbootimg3/mkbootimg.py"
    local MONTH="$(date +%Y-%m)"
    
    if [ ! -f "$MKBOOTIMG" ]; then
        echo "WARNING: mkbootimg not found at $MKBOOTIMG, skipping boot.img generation"
        return 1
    fi
    
    if [ ! -f "$OUTDIR/arch/arm64/boot/Image" ]; then
        echo "WARNING: Kernel Image not found, skipping boot.img generation"
        return 1
    fi
    
    echo "INFO: Generating GKI boot.img..."
    python3 "$MKBOOTIMG" \
        --kernel "$OUTDIR/arch/arm64/boot/Image" \
        --header_version 4 \
        --os_version 15.0.0 \
        --os_patch_level "$MONTH" \
        --pagesize 4096 \
        -o "$IMAGES_DIR/boot.img"
    
    if [ -f "$IMAGES_DIR/boot.img" ]; then
        echo "INFO: Created boot.img ($(du -h "$IMAGES_DIR/boot.img" | cut -f1))"
        return 0
    else
        echo "WARNING: Failed to create boot.img"
        return 1
    fi
}

build_vendor_boot() {
    if [ "$DO_VENDOR_BOOT" != "1" ]; then
        return 0
    fi
    
    export COMMON_OUT="$IMAGES_DIR"
    
    if [ -f "$KDIR/kernel_build/scripts/vboot.sh" ]; then
        "$KDIR/kernel_build/scripts/vboot.sh"
    else
        echo "ERROR: vboot.sh not found, skipping vendor_boot"
        return 1
    fi
}
