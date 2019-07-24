#!/usr/bin/env bash
# Drone CI Clang pipeline - build script

# Log all commands executed and exit on error, including pieps
set -veo pipefail

# Build
time ./build-proton-tc.sh |& tee build.log

# Generate build info
rel_date="$(date "+%Y%m%e")" # ISO 8601 format
rel_friendly_date="$(date "+%B %d, %Y")" # "Month day, year" format
pushd llvm-project
short_commit="$(cut -c-8 <<< "$(git rev-parse HEAD)")"
popd

# Generate product name
product_desc="proton_clang-$rel_date-$short_commit"
product_name="$product_desc.tar.zst"

# Create tar.zst package
mv install "$product_desc"
tar cf - "$product_desc" | zstd -T0 - -o "$product_name"

# Find size of package
product_size="$(du -h --apparent-size "$product_name" | awk '{print $1}')"

# Write variables to disk for use by integrations
echo "$rel_date" > rel_date.txt
echo "$rel_friendly_date" > rel_friendly_date.txt
echo "$product_name" > product_name.txt
echo "$product_size" > product_size.txt
