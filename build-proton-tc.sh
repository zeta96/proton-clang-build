#!/usr/bin/env bash
# Script to build a toolchain specialized for Proton Kernel development

# Exit on error
set -e

# Function to show an informational message
function msg() {
    echo -e "\e[1;32m$@\e[0m"
}

# Build LLVM
msg "Building LLVM..."
./build-llvm.py \
	--clang-vendor "Proton" \
	--projects "clang;compiler-rt;lld;polly" \
	--targets "AArch64;ARM" \
	--march "skylake" \
	--pgo

# Build binutils
msg "Building binutils..."
./build-binutils.py \
	--targets arm aarch64

# Remove unused products
msg "Removing unused products..."
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
msg "Stripping remaining products..."
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip ${f: : -1}
done
