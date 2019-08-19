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
	llvm_args=(--targets "ARM;AArch64;X86" --shallow-clone)
	binutils_args=(--targets arm aarch64 x86_64 --shallow-clone)
else
	msg "Configuring full-fledged LLVM build..."
	llvm_args=(--targets "ARM;AArch64;X86" --march "native" --lto full)
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
msg "Removing unused products..."
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
msg "Stripping remaining products..."
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip ${f: : -1}
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
msg "Setting library load paths for portability..."
for bin in $(find install -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	if ldd "$bin" | grep -q "not found"; then
		echo "Setting rpath on $bin"
		patchelf --set-rpath '$ORIGIN/../lib' "$bin"
	fi
done
