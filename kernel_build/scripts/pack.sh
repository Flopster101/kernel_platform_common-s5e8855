#!/bin/bash
#
# Packaging functions for Odin tar files
#

create_odin_tar() {
    echo -e "\nINFO: Creating Odin tar package(s)..."
    
    if [ ! -f "$IMAGES_DIR/boot.img" ]; then
        echo "WARNING: No boot.img found, skipping tar creation"
        return 1
    fi
    
    # Collect files to package
    local tar_files="boot.img"
    local tar_desc="boot.img"
    
    # Build variant name (lowercase)
    local variant_name=$(echo "$KERNEL_VARIANT" | tr '[:upper:]' '[:lower:]')
    
    # Add GKI suffix if GKI-only build
    if [ "$DO_GKI_ONLY" == "1" ]; then
        variant_name="${variant_name}-gki"
    fi
    
    if [ "$DO_VENDOR_BOOT" == "1" ] && [ -f "$IMAGES_DIR/vendor_boot.img" ]; then
        tar_files="$tar_files vendor_boot.img"
        tar_desc="$tar_desc + vendor_boot.img"
    fi
    
    # Add dtbo.img if it exists
    if [ -f "$IMAGES_DIR/dtbo.img" ]; then
        tar_files="$tar_files dtbo.img"
        tar_desc="$tar_desc + dtbo.img"
    fi

    TAR_NAME="$KDIR/gts10fewifi-${variant_name}-${DATE}.tar"
    
    echo "INFO: Packaging $tar_desc..."
    tar -C "$IMAGES_DIR" -cf "$TAR_NAME" $tar_files
    echo "INFO: Created: $(basename "$TAR_NAME") ($(du -h "$TAR_NAME" | cut -f1))"
    echo "INFO: Ready to flash with Odin!"
    
    return 0
}
