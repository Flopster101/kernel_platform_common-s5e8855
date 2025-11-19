#!/usr/bin/env bash
# DTB/DTBO builder - packages device trees into dtbo.img

set -e

if [ -z "$KDIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    KDIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

OUT_DIR="${OUT_DIR:-$KDIR/out}"
DTB_DIR="$OUT_DIR/arch/arm64/boot/dts/exynos"
DTBO_BASE_DIR="$OUT_DIR/arch/arm64/boot/dts/samsung"
DTB_OUT="$OUT_DIR/dtb"
DTBO_OUT="$OUT_DIR/dtbo"

DTB_NAME="${DTB_NAME:-s5e8855.dtb}"

echo "==> Building DTB/DTBO..."

mkdir -p "$DTB_OUT" "$DTBO_OUT"

# Copy main DTB
if [ ! -f "$DTB_DIR/$DTB_NAME" ]; then
    echo "ERROR: $DTB_NAME not found"
    exit 1
fi

cp "$DTB_DIR/$DTB_NAME" "$DTB_OUT/"

# Build dtbo.img with all device overlays
MKDTBOIMG="$KDIR/kernel_build/tools/libufdt/mkdtboimg.py"
MKDTBO_CMD="python3 $MKDTBOIMG create $DTBO_OUT/dtbo.img --page_size=2048"

# Scan all device dirs and collect DTBOs
for device_dir in "$DTBO_BASE_DIR"/*; do
    [ -d "$device_dir" ] || continue
    
    for dtbo_file in "$device_dir"/*.dtbo; do
        [ -f "$dtbo_file" ] || continue
        
        dtbo_name=$(basename "$dtbo_file")
        cp "$dtbo_file" "$DTBO_OUT/"
        
        # Read hw_rev range from DTBO metadata
        hw_min=$(fdtget "$dtbo_file" / dtbo-hw_rev 2>/dev/null || echo "0")
        hw_max=$(fdtget "$dtbo_file" / dtbo-hw_rev_end 2>/dev/null || echo "$hw_min")
        
        MKDTBO_CMD="$MKDTBO_CMD $DTBO_OUT/$dtbo_name --custom0=$hw_min --custom1=$hw_max"
    done
done

eval $MKDTBO_CMD

echo "INFO: Created dtbo.img ($(du -h "$DTBO_OUT/dtbo.img" | cut -f1))"
