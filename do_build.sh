#!/bin/bash
#
# Wrapper script for ckbuild.sh
#

# Verify we're in the kernel directory
if [ ! -d "kernel_build" ] || [ ! -f "Makefile" ]; then
    echo "ERROR: This script must be run from the top-level kernel directory"
    exit 1
fi

# Set workspace to parent directory (can be overridden by user)
export WP="${WP:-$(realpath $PWD/..)}"

# Pass all arguments to ckbuild.sh
./kernel_build/ckbuild.sh "$@"
