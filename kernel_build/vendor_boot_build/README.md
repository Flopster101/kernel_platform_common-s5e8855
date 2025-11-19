# vendor_boot Build System

This directory contains the configuration for building `vendor_boot.img` for the Samsung Galaxy Tab S10 FE WiFi (gts10fewifi).

## Directory Structure

```
vendor_boot_build/
├── dlkm/
│   └── modules.load          # List of modules for DLKM ramdisk (4K page size)
├── 16k/
│   └── modules.load          # List of modules for 16K page size ramdisk
├── bootconfig                # Bootconfig file from stock
├── stock_ramdisk00.lz4       # Stock platform ramdisk (SELinux policies, firmware, etc)
├── stock_dtb.dtb             # Stock DTB from vendor_boot (must match stock DTBO)
└── README.md                 # This file
```

## vendor_boot.img Structure

The generated `vendor_boot.img` contains three ramdisks matching the stock firmware:

1. **Ramdisk 00** (type `0x1`, platform): Stock platform ramdisk with SELinux policies, firmware, init scripts, etc.
2. **Ramdisk 01** (type `0x3`, name `dlkm`): Our built DLKM modules for 4K page size (~405 modules) - **USED BY SYSTEM**
3. **Ramdisk 02** (type `0x3`, name `16K`): Our built modules for 16K page size (~405 modules) - **NOT USED** (4K kernel)

**Note**: This is a 4K page size kernel, so only ramdisk01 (DLKM) is used. Ramdisk02 (16K) must exist for compatibility but is not loaded. The DLKM ramdisk includes all modules (DLKM + vendor_dlkm modules) to avoid needing a separate vendor_dlkm partition.

## Building

### Build kernel only (creates boot.img + boot-only tar)
```bash
cd common
./build_kernel.sh
```

### Build kernel + vendor_boot (creates boot.img + vendor_boot.img + combined tar)
```bash
cd common
./build_kernel.sh v
```

### Build vendor_boot only (after kernel build)
```bash
cd common
export COMMON_OUT=out_images
./build_vendor_boot.sh
```

## Module Lists

The `modules.load` files were extracted from stock firmware (AYG5) and modified:
- **dlkm/modules.load**: Based on stock 16K modules.load + scsc_bt.ko (~405 modules)
  - Includes all DLKM modules
  - Plus vendor_dlkm modules (Bluetooth, WiFi, Camera, Audio, Modem, etc.)
  - Added scsc_bt.ko for Bluetooth support
  - This is the ramdisk that's actually used by the 4K kernel
- **16k/modules.load**: Stock 16K modules.load (~405 modules)
  - Required for compatibility but not used by 4K kernel
  - Could potentially be emptied to save space

The build script:
1. Finds the most recent kernel module build
2. Creates a fast lookup table of all built modules
3. Copies and strips modules according to `modules.load`
4. Generates `modules.dep` for each ramdisk with depmod
5. Creates LZ4-compressed cpio archives
6. Assembles `vendor_boot.img` using mkbootimg

## Missing Modules

Some modules listed in `modules.load` may not be built (e.g., vendor-specific drivers not in the source tree). The script will warn about these but continue building. Missing modules include:

- `exynos_mct_v3.ko` - Timer driver (v3 variant not in source)
- `sgpu.ko` - GPU driver (vendor binary)
- `ufs-sec-driver.ko` - Samsung UFS driver
- `snd-soc-samsung-vts*.ko` - Voice trigger drivers
- Audio-related modules (may be vendor-specific)

These modules are typically provided as prebuilts in vendor partitions or may have different names in the open-source kernel.

## Output

### Images (`common/out_images/`)
- **boot.img**: GKI boot image (~36 MB)
- **vendor_boot.img**: Vendor boot with modules (~49 MB)
- **dtbo.img**: Device tree overlay image (~916 KB, 5 DTBOs)

### vendor_boot.img Details
- **Size**: ~49 MB
- **Header version**: 4
- **DTB**: Included from `s5e8855.dtb`
- **Bootconfig**: Included
- **Vendor cmdline**: `panic_on_warn=0 bootconfig loop.max_part=7`

### DTB in vendor_boot.img
- **Source**: Stock DTB extracted from stock vendor_boot (AYG5)
- **Size**: ~266 KB
- **Note**: Stock DTB must be used to match stock DTBO in boot.img
  - DTB and DTBO must be compatible for device tree overlay to apply correctly
  - Stock DTBO remains in boot.img (not rebuilt)
  - Using stock DTB ensures boot compatibility

## Notes

- Stock ramdisk00 (platform ramdisk) is used directly from stock vendor_boot
  - Contains SELinux policies, firmware, init scripts, fstab, etc.
  - Size: ~27 MB compressed, ~54 MB uncompressed
- Stock DTB is used from stock vendor_boot (bare DTB format, not DTBO)
- Ramdisk01 (dlkm) and ramdisk02 (16K) are rebuilt with our modules
- Module metadata (modules.dep, modules.alias, modules.softdep) is generated with depmod
  - Ensures correct dependencies for our rebuilt modules
  - Stock modules.load is used to define explicit load order
- Module stripping is done with `llvm-strip --strip-debug` to reduce size
- Build time: ~9-10 seconds (after kernel build)
- The script uses bash associative arrays for fast module lookup

## Important Config Notes

- `CONFIG_EXYNOS_PM_DOMAINS` must be disabled to avoid conflict with `CONFIG_EXYNOS_PD` module
  - Both register as "exynos-pd" driver and cause boot failure if both enabled
  - Disabled in arch/arm64/Kconfig.platforms to prevent "select" from re-enabling it


## Odin Packages

The build script automatically creates Odin-flashable tar packages:

### Boot only
- **Filename**: `gts10fewifi-boot-YYYYMMDD-HHMM.tar` (~37 MB)
- **Contains**: `boot.img` + `dtbo.img`
- **Flash to**: AP slot in Odin

### Boot + vendor_boot
- **Filename**: `gts10fewifi-boot-vboot-YYYYMMDD-HHMM.tar` (~85 MB)
- **Contains**: `boot.img` + `vendor_boot.img` + `dtbo.img`
- **Flash to**: AP slot in Odin

The tar files are created in the `common/` directory and are ready to flash directly with Odin.
