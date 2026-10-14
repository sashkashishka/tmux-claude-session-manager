#!/usr/bin/env bash
# Builds the vendored claude-session-manager (csm) into the plugin dir if it's missing or stale. Requires Go.

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# Only one build at a time (the config may be sourced several times).
mkdir "$BUILD_LOCK" 2>/dev/null || exit 0
trap 'rmdir "$BUILD_LOCK"' EXIT
: >"$BUILD_LOG"

msg() {
	echo "==> $*" >>"$BUILD_LOG"
	tmux display-message "claude-session-manager: $*"
}

# Errors stay on screen until a key is pressed.
err() {
	echo "==> ERROR: $*" >>"$BUILD_LOG"
	tmux display-message -d 0 "claude-session-manager error: $*"
	exit 1
}

binary_current && exit 0

if ! command -v go >/dev/null; then
	err "Go is required but was not found. Install it (https://go.dev/dl or brew install go), then press prefix + $(get_opt @csm-key Y)"
fi

hash="$(source_hash)"
msg "building csm (the first build downloads its Go modules)…"
mkdir -p "$BUILD_ROOT/bin"
# Build next to the binary and swap it in: on Apple Silicon, overwriting a
# binary in place invalidates its cached code signature and it dies with SIGKILL.
if (cd "$SOURCE_DIR" && go build -trimpath -ldflags "-s -w" -o "$BINARY.new" .) >>"$BUILD_LOG" 2>&1; then
	rm -f "$BINARY"
	mv "$BINARY.new" "$BINARY"
	echo "$hash" >"$BUILT_HASH_FILE"
	msg "built. Press prefix + $(get_opt @csm-key Y) to open"
else
	rm -f "$BINARY.new"
	err "build failed, see $BUILD_LOG"
fi
