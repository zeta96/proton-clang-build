#!/usr/bin/env bash
# Drone CI Clang pipeline - Telegram integration script

# Helper function to send a Telegram message
function tg_send() {
    local msg_type="$1"
    shift

    local args=()
    for arg in "$@"; do
        args+=(-F "$arg")
    done

    curl -sf --form-string chat_id="$TG_CHAT_ID" \
        "${args[@]}" \
        "https://api.telegram.org/bot$TG_BOT_TOKEN/send$msg_type" \
        > /dev/null
}

# Log all commands executed and exit on error, including pieps
set -veo pipefail

# Generate build descriptor
pushd llvm-project
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<< $llvm_commit)"
popd

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$llvm_commit"
build_url="https://cloud.drone.io/$DRONE_REPO_NAMESPACE/$DRONE_REPO_NAME/$DRONE_BUILD_NUMBER/1/3"
build_desc="[Build #$DRONE_BUILD_NUMBER]($build_url) on LLVM commit [$short_llvm_commit]($llvm_commit_url)"

# Get elapsed time
time_after="$(date +%s)"
time_delta="$((time_after-DRONE_BUILD_STARTED))"
time_elapsed="$((time_delta/60%60))m$((time_delta%60))s"

# On success
if [[ "$DRONE_JOB_STATUS" == "success" ]]; then
    # Read GitHub asset URL and size from disk
    asset_url="$(cat asset_url.txt)"
    product_size="$(cat product_size.txt)"

    # Send success message with link to uploaded asset
    tg_send Message parse_mode=Markdown disable_web_page_preview=true text="$build_desc *succeeded* after $time_elapsed. [Download toolchain from GitHub]($asset_url) ($product_size)"

# On failure
elif [[ "$DRONE_JOB_STATUS" == "failure" ]]; then
    # Send error message
    tg_send Message parse_mode=Markdown text="$build_desc *failed* after $time_elapsed." disable_web_page_preview=true

# On unknown status
else
    echo "Unknown job status '$DRONE_JOB_STATUS'; bailing."

    # Send error message
    tg_send Message parse_mode=Markdown text="$build_desc finished with *unknown status* `$DRONE_JOB_STATUS` after $time_elapsed." disable_web_page_preview=true

    exit 1
fi
