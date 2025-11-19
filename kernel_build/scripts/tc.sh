#!/bin/bash
#
# Toolchain management
# Supports: aosp (latest), aosp-r510928 (recommended for android15-6.6)
#

# Toolchain URLs
AOSP_LIST="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+/mirror-goog-main-llvm-toolchain-source"
AOSP_ARCHIVE="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/mirror-goog-main-llvm-toolchain-source"
AOSP_R510928_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/513791fb7edceb387ab12b9d29a9ccbe01cae193/clang-r510928.tar.gz"

# Toolchain directory
export TC_DIR="$WP/toolchains"

# Toolchain directories
AC_DIR="$TC_DIR/aospclang"
AC_R510928_DIR="$TC_DIR/aospclang-r510928"

# Default to r510928
if [ -z "$CLANG_TYPE" ]; then
    export CLANG_TYPE="aosp-r510928"
fi

get_toolchain() {
    local toolchain_type="$1"
    local toolchain_dir=""
    
    case "$toolchain_type" in
        aosp)
            toolchain_dir="$AC_DIR"
            if [ ! -d "$toolchain_dir" ] || [ ! -f "$toolchain_dir/bin/clang" ]; then
                echo -e "\nINFO: Latest AOSP Clang not found! Downloading to $toolchain_dir..."
                
                # Scrape the HTML directory listing to find latest clang
                HTML=$(curl -s "$AOSP_LIST")
                CURRENT_CLANG=$(
                    printf '%s\n' "$HTML" \
                    | grep -oP 'href="[^"]*clang-r[0-9]+/' \
                    | grep -oP 'clang-r[0-9]+' \
                    | sort -V \
                    | tail -n1
                )
                
                if [ -z "$CURRENT_CLANG" ]; then
                    echo "ERROR: Couldn't find any clang-r### dirs in $AOSP_LIST" >&2
                    exit 1
                fi
                
                echo "INFO: Latest AOSP Clang is $CURRENT_CLANG, downloading..."
                if ! wget -nv --show-progress -O "${CURRENT_CLANG}.tar.gz" "${AOSP_ARCHIVE}/${CURRENT_CLANG}.tar.gz"; then
                    echo "ERROR: Download failed! Aborting..."
                    exit 1
                fi
                
                mkdir -p "$toolchain_dir"
                tar -xf "${CURRENT_CLANG}.tar.gz" -C "$toolchain_dir" || {
                    echo "ERROR: Extraction failed!"
                    rm -f "${CURRENT_CLANG}.tar.gz"
                    exit 1
                }
                rm "${CURRENT_CLANG}.tar.gz"
                
                # Create dummy elfedit binaries (required by kernel build)
                touch "$toolchain_dir/bin/aarch64-linux-gnu-elfedit"
                chmod +x "$toolchain_dir/bin/aarch64-linux-gnu-elfedit"
                touch "$toolchain_dir/bin/arm-linux-gnueabi-elfedit"
                chmod +x "$toolchain_dir/bin/arm-linux-gnueabi-elfedit"
                
                echo "INFO: AOSP Clang downloaded successfully"
            fi
            ;;
        aosp-r510928)
            toolchain_dir="$AC_R510928_DIR"
            if [ ! -d "$toolchain_dir" ] || [ ! -f "$toolchain_dir/bin/clang" ]; then
                echo -e "\nINFO: AOSP Clang r510928 not found! Downloading to $toolchain_dir..."
                
                local CLANG_TAR="$TC_DIR/clang-r510928.tar.gz"
                
                if [ ! -f "$CLANG_TAR" ]; then
                    echo "INFO: Downloading from: $AOSP_R510928_URL"
                    if command -v wget &> /dev/null; then
                        wget -nv --show-progress -O "$CLANG_TAR" "$AOSP_R510928_URL" || {
                            echo "ERROR: Failed to download clang"
                            rm -f "$CLANG_TAR"
                            exit 1
                        }
                    elif command -v curl &> /dev/null; then
                        curl -L -o "$CLANG_TAR" "$AOSP_R510928_URL" || {
                            echo "ERROR: Failed to download clang"
                            rm -f "$CLANG_TAR"
                            exit 1
                        }
                    else
                        echo "ERROR: Neither wget nor curl found. Please install one of them."
                        exit 1
                    fi
                else
                    echo "INFO: Using cached tarball: $CLANG_TAR"
                fi
                
                mkdir -p "$toolchain_dir"
                tar -xzf "$CLANG_TAR" -C "$toolchain_dir" || {
                    echo "ERROR: Failed to extract clang"
                    rm -rf "$toolchain_dir"
                    exit 1
                }
                
                # Verify extraction
                if [ ! -f "$toolchain_dir/bin/clang" ]; then
                    echo "ERROR: Clang extraction failed - clang binary not found"
                    rm -rf "$toolchain_dir"
                    exit 1
                fi
                
                # Create dummy elfedit binaries (required by kernel build)
                touch "$toolchain_dir/bin/aarch64-linux-gnu-elfedit"
                chmod +x "$toolchain_dir/bin/aarch64-linux-gnu-elfedit"
                touch "$toolchain_dir/bin/arm-linux-gnueabi-elfedit"
                chmod +x "$toolchain_dir/bin/arm-linux-gnueabi-elfedit"
                
                echo "INFO: AOSP Clang r510928 downloaded successfully"
            fi
            ;;
        *)
            echo -e "\nERROR: Unknown toolchain type: $toolchain_type"
            echo "INFO: Supported types: aosp, aosp-r510928"
            exit 1
            ;;
    esac
}

prep_toolchain() {
    local toolchain_type="$1"
    local toolchain_dir=""
    
    case "$toolchain_type" in
        aosp)
            toolchain_dir="$AC_DIR"
            echo "INFO: Toolchain: Latest AOSP Clang"
            ;;
        aosp-r510928)
            toolchain_dir="$AC_R510928_DIR"
            echo "INFO: Toolchain: AOSP Clang r510928 (recommended for android15-6.6)"
            ;;
        *)
            echo "ERROR: Unknown toolchain type: $toolchain_type"
            exit 1
            ;;
    esac
    
    export PATH="${toolchain_dir}/bin:${PATH}"
    export LD_LIBRARY_PATH="${toolchain_dir}/lib:${LD_LIBRARY_PATH}"
    
    # Clang setup
    export CLANG_TRIPLE="aarch64-linux-gnu-"
    export CROSS_COMPILE="aarch64-linux-gnu-"
    export CROSS_COMPILE_COMPAT="arm-linux-gnueabi-"
    export CC="clang"
    export LD="ld.lld"
    export AR="llvm-ar"
    export AS="llvm-as"
    export NM="llvm-nm"
    export OBJCOPY="llvm-objcopy"
    export OBJDUMP="llvm-objdump"
    export READELF="llvm-readelf"
    export OBJSIZE="llvm-size"
    export STRIP="llvm-strip"
    export HOSTCC="clang"
    export HOSTCXX="clang++"
    export HOSTAR="llvm-ar"
    export HOSTLD="ld.lld"
    
    # Get compiler version
    KBUILD_COMPILER_STRING=$("${toolchain_dir}/bin/clang" --version | head -n 1 | sed 's/(https.*//' | sed 's/ version//')
    export KBUILD_COMPILER_STRING
    
    echo "INFO: Compiler: $KBUILD_COMPILER_STRING"
}

## Pre-build dependencies
get_toolchain "$CLANG_TYPE"
prep_toolchain "$CLANG_TYPE"
