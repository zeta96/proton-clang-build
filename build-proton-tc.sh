#!/usr/bin/env bash
# Script to build a toolchain specialized for Proton Kernel development

# Exit on error
set -e

# Function to show an informational message
function msg() {
    echo -e "\e[1;32m$@\e[0m"
}

# Configure LLVM build based on environment or arguments
if [[ "$1" == "--ci" ]] || [[ "$DRONE" == "true" ]]; then
	msg "Configuring reduced LLVM build for CI..."
	llvm_args=(--targets "ARM;AArch64" --shallow-clone)
	binutils_args=(--targets arm aarch64 --shallow-clone)
else
	msg "Configuring full-fledged LLVM build..."
	llvm_args=(--targets "ARM;AArch64;X86" --march "native")
	binutils_args=(--targets arm aarch64 x86_64)
fi

# Build LLVM
msg "Building LLVM..."
./build-llvm.py \
	--clang-vendor "Proton" \
	--projects "clang;compiler-rt;lld;polly" \
	--pgo \
	"${llvm_args[@]}"

# Build binutils
msg "Building binutils..."
./build-binutils.py \
	"${binutils_args[@]}"

# Remove unused products
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
msg "Stripping products..."
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip ${f: : -1}
done
