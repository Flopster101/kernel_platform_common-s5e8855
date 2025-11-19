#!/bin/bash
#
# vendor_boot.img builder for s5e8855 (android15-6.6)
#

set -e

# Config
EMPTY_16K=true  # This is a 4K kernel, so 16K ramdisk is just a placeholder

# Paths
SCRIPT_DIR="$(readlink -f $(dirname "$0"))"

VBOOT_DIR="$(readlink -f "$SCRIPT_DIR/../vendor_boot_build")"
TMPDIR="$KDIR/vendor_boot_tmp"
OUTDIR="${COMMON_OUT:-$KDIR/out_images}"
MOD_OUTDIR="$OUTDIR/modules"

# Input files
BOOTCONFIG="$VBOOT_DIR/bootconfig"
STOCK_RAMDISK00="$VBOOT_DIR/stock_ramdisk00.lz4"
DTB="$OUTDIR/s5e8855.dtb"
K16_MODULES_LOAD="$VBOOT_DIR/16k/modules.load"

# Output
VENDOR_BOOT_IMG="$OUTDIR/vendor_boot.img"

# Ramdisk dirs
DLKM_RAMDISK_DIR="$TMPDIR/ramdisk_dlkm"
K16_RAMDISK_DIR="$TMPDIR/ramdisk_16k"
DLKM_MODULES_DIR="$DLKM_RAMDISK_DIR/lib/modules"
K16_MODULES_DIR="$K16_RAMDISK_DIR/lib/modules"

# Tools
MKBOOTIMG="${MKBOOTIMG:-$HOME/Escritorio/TOOLS/mkbootimg3/mkbootimg.py}"
STRIP="${STRIP:-llvm-strip}"

# Check if llvm-strip exists
if ! command -v "$STRIP" &> /dev/null; then
    PREBUILT_CLANG="$KDIR/../prebuilts/clang/host/linux-x86/clang-r510928"
    if [ -f "$PREBUILT_CLANG/bin/llvm-strip" ]; then
        STRIP="$PREBUILT_CLANG/bin/llvm-strip"
    else
        echo "ERROR: llvm-strip not found"
        exit 1
    fi
fi

# Sanity checks
if [ ! -f "$MKBOOTIMG" ]; then
    echo "ERROR: mkbootimg not found at $MKBOOTIMG"
    exit 1
fi

if [ ! -d "$MOD_OUTDIR" ]; then
    echo "ERROR: Modules directory not found at $MOD_OUTDIR"
    exit 1
fi

if [ ! -f "$DTB" ]; then
    echo "ERROR: DTB not found at $DTB"
    exit 1
fi

if [ ! -f "$STOCK_RAMDISK00" ]; then
    echo "ERROR: Stock ramdisk00 not found at $STOCK_RAMDISK00"
    echo "Extract it from stock vendor_boot first"
    exit 1
fi

echo "========================================"
echo "INFO: Building vendor_boot.img"
echo "========================================"

# Clean temp dir
rm -rf "$TMPDIR"

# Find module directory
LATEST_MOD_DIR=$(ls -td "$MOD_OUTDIR/lib/modules"/*/ 2>/dev/null | head -1 | sed 's:/$::')
if [ -z "$LATEST_MOD_DIR" ]; then
    echo "ERROR: No module directory found in $MOD_OUTDIR"
    exit 1
fi
MOD_VER=$(basename "$LATEST_MOD_DIR")

# Generate modules.load from modules.order
mkdir -p "$TMPDIR"
DLKM_MODULES_LOAD="$TMPDIR/modules.load"
echo "INFO: Generating modules.load from $MOD_VER..."
"$KDIR/kernel_build/scripts/gen_modules_load.sh" "$LATEST_MOD_DIR" "$DLKM_MODULES_LOAD"
echo "INFO: Generated modules.load with $(wc -l < "$DLKM_MODULES_LOAD") modules"

# Create ramdisk dirs
mkdir -p "$DLKM_MODULES_DIR"
K16_MOD_VER="${MOD_VER}_16k"
K16_MODULES_DIR="$K16_RAMDISK_DIR/lib/modules/$K16_MOD_VER"
mkdir -p "$K16_MODULES_DIR"

# Build module lookup table
declare -gA MODULE_MAP
while IFS= read -r path; do
    name=$(basename "$path")
    MODULE_MAP["$name"]="$path"
done < <(find "$LATEST_MOD_DIR" -name "*.ko" -type f)

# Copy and strip modules
copy_modules() {
    local modules_load="$1"
    local dest_dir="$2"
    local ramdisk_name="$3"
    
    local count=0
    local missing=0
    local missing_list=""
    
    local modules=($(grep -v "^#" "$modules_load" | grep -v "^$"))
    local total=${#modules[@]}
    
    for module in "${modules[@]}"; do
        local src="${MODULE_MAP[$module]}"
        
        if [ -f "$src" ]; then
            "$STRIP" --strip-debug "$src" -o "$dest_dir/$module" 2>/dev/null || {
                echo "ERROR: Failed to strip $module"
                exit 1
            }
            count=$((count + 1))
        else
            missing_list="$missing_list $module"
            missing=$((missing + 1))
        fi
    done
    
    if [ $missing -gt 0 ]; then
        echo "WARNING: Missing $missing modules for $ramdisk_name:$missing_list"
    fi
}

# Copy modules
echo "INFO: Copying and stripping DLKM modules..."
copy_modules "$DLKM_MODULES_LOAD" "$DLKM_MODULES_DIR" "DLKM"

if [ "$EMPTY_16K" != true ]; then
    echo "INFO: Copying and stripping 16K modules..."
    copy_modules "$K16_MODULES_LOAD" "$K16_MODULES_DIR" "16K"
fi

# Generate module metadata files
echo "INFO: Generating module metadata (depmod)..."
# DLKM: flat structure (modules directly in lib/modules/)
# depmod needs versioned subdirs, so we create temp structure
DLKM_TEMP_DIR="$DLKM_RAMDISK_DIR/lib/modules/$MOD_VER"
mkdir -p "$DLKM_TEMP_DIR"
mv "$DLKM_MODULES_DIR"/*.ko "$DLKM_TEMP_DIR/" 2>/dev/null || true
depmod -a -b "$DLKM_RAMDISK_DIR" "$MOD_VER" 2>/dev/null || true
# Fix paths to be flat
if [ -f "$DLKM_TEMP_DIR/modules.dep" ]; then
    sed -i "s|/lib/modules/$MOD_VER/|/lib/modules/|g" "$DLKM_TEMP_DIR/modules.dep"
fi
# Move back to flat structure
mv "$DLKM_TEMP_DIR"/* "$DLKM_MODULES_DIR/" 2>/dev/null || true
rmdir "$DLKM_TEMP_DIR"
cp "$DLKM_MODULES_LOAD" "$DLKM_MODULES_DIR/modules.load"

# 16K ramdisk
if [ "$EMPTY_16K" = true ]; then
    touch "$K16_MODULES_DIR/modules.load"
else
    depmod -a -b "$K16_RAMDISK_DIR" "$K16_MOD_VER" 2>/dev/null || true
    if [ -f "$K16_MODULES_DIR/modules.dep" ]; then
        sed -i "s|^\([^/]\)|/lib/modules/$K16_MOD_VER/\1|g" "$K16_MODULES_DIR/modules.dep"
    fi
    cp "$K16_MODULES_LOAD" "$K16_MODULES_DIR/modules.load"
fi

# Clean up unnecessary depmod files
for dir in "$DLKM_MODULES_DIR" "$K16_MODULES_DIR"; do
    for f in "$dir"/modules.*; do
        [ -f "$f" ] || continue
        fname=$(basename "$f")
        if [[ "$fname" != "modules.dep" && "$fname" != "modules.softdep" && "$fname" != "modules.alias" && "$fname" != "modules.load" ]]; then
            rm -f "$f"
        fi
    done
done

# Create ramdisk archives
echo "INFO: Creating ramdisk archives..."
(cd "$DLKM_RAMDISK_DIR" && find . | cpio --quiet -o -H newc -R root:root | lz4 -9cl > "$TMPDIR/ramdisk_dlkm.lz4")
(cd "$K16_RAMDISK_DIR" && find . | cpio --quiet -o -H newc -R root:root | lz4 -9cl > "$TMPDIR/ramdisk_16k.lz4")

# Build vendor_boot.img
echo "INFO: Building vendor_boot.img with mkbootimg..."
MONTH="$(date +%Y-%m)"

python3 "$MKBOOTIMG" \
    --header_version 4 \
    --pagesize 2048 \
    --vendor_boot "$VENDOR_BOOT_IMG" \
    --dtb "$DTB" \
    --vendor_bootconfig "$BOOTCONFIG" \
    --vendor_cmdline "panic_on_warn=0 bootconfig loop.max_part=7" \
    --board "SRPXK12C004" \
    --ramdisk_type platform \
    --vendor_ramdisk "$STOCK_RAMDISK00" \
    --ramdisk_type dlkm \
    --ramdisk_name dlkm \
    --vendor_ramdisk_fragment "$TMPDIR/ramdisk_dlkm.lz4" \
    --ramdisk_type dlkm \
    --ramdisk_name 16K \
    --vendor_ramdisk_fragment "$TMPDIR/ramdisk_16k.lz4" \
    --os_version 15.0.0 \
    --os_patch_level "$MONTH"

if [ $? -eq 0 ]; then
    echo "========================================"
    echo "INFO: vendor_boot.img created!"
    echo "========================================"
    rm -rf "$TMPDIR"
else
    echo "ERROR: Failed to create vendor_boot.img"
    exit 1
fi
