#!/usr/bin/env bash
# Drone CI Clang pipeline - GitHub integration script

# Helper function to perform a GitHub API call
function gh_call() {
    local req="$1"
    local server="$2"
    local endpoint="$3"
    shift
    shift
    shift

    resp="$(curl -fu "$DRONE_REPO_NAMESPACE:$GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -X "$req" \
        "https://$server.github.com/repos/$DRONE_REPO_NAMESPACE/$DRONE_REPO_NAME/$endpoint" \
        "$@")" || \
        { ret="$?"; echo "Request failed with exit code $ret:"; cat <<< "$resp"; return $ret; }

    cat <<< "$resp"
}

# Log all commands executed and exit on error, including pieps
set -veo pipefail

# Generate release info
rel_date="$(cat rel_date.txt)" # ISO 8601 format
rel_friendly_date="$(cat rel_friendly_date.txt)" # "Month day, year" format
build_url="https://cloud.drone.io/$DRONE_REPO_NAMESPACE/$DRONE_REPO_NAME/$DRONE_BUILD_NUMBER/1/3"

pushd llvm-project
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<< $llvm_commit)"
popd

pushd binutils
binutils_commit="$(git rev-parse HEAD)"
short_binutils_commit="$(cut -c-8 <<< $binutils_commit)"
popd

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$llvm_commit"
binutils_commit_url="https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=$binutils_commit"

# Delete the existing release if necessary
resp="$(gh_call GET api "releases/tags/$rel_date" -sS)" && \
    old_rel_id="$(jq .id <<< "$resp")" && \
    gh_call DELETE api "releases/$old_rel_id" -sS

# Create new release
payload="$(cat <<END
{
    "tag_name": "$rel_date",
    "target_commitish": "$DRONE_BRANCH",
    "name": "$rel_friendly_date",
    "body": "Automated [build]($build_url) (job $DRONE_BUILD_NUMBER) of LLVM + Clang as of commit [$short_llvm_commit]($llvm_commit_url) and binutils as of commit [$short_binutils_commit]($binutils_commit_url)."
}
END
)"
resp="$(gh_call POST api "releases" --data-binary "@-" -sS <<< "$payload")"
rel_url="$(jq -r .html_url <<< "$resp")"
rel_id="$(jq .id <<< "$resp")"
echo "Release created: $rel_url"
echo "Release ID: $rel_id"

# Upload build as asset
product_name="$(cat product_name.txt)"
resp="$(gh_call POST uploads "releases/$rel_id/assets?name=$product_name" -H "Content-Type: application/zstd" --data-binary "@$product_name")"
asset_url="$(jq -r .browser_download_url <<< "$resp")"
echo "Direct download link: $asset_url"

# Write asset URL to disk for later use
echo "$asset_url" > asset_url.txt
