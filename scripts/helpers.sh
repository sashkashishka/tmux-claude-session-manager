# Shared helpers, sourced by the other scripts.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$PLUGIN_DIR/vendor/claude-session-manager"
BUILD_ROOT="$PLUGIN_DIR/.build-root"
BINARY="$BUILD_ROOT/bin/csm"
BUILT_HASH_FILE="$BUILD_ROOT/source.sha"
BUILD_LOG="$PLUGIN_DIR/build.log"
BUILD_LOCK="$PLUGIN_DIR/.build.lock"

# The tmux server's environment often lacks the user's shell PATH.
export PATH="$HOME/go/bin:/usr/local/go/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

get_opt() {
	local value
	value="$(tmux show-option -gqv "$1")"
	echo "${value:-$2}"
}

# Hash of the vendored sources, so edits (or a plugin update) trigger a rebuild.
source_hash() {
	(cd "$SOURCE_DIR" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum | shasum | cut -d' ' -f1)
}

# True when the binary exists and was built from the current sources.
binary_current() {
	[ -x "$BINARY" ] && [ "$(cat "$BUILT_HASH_FILE" 2>/dev/null)" = "$(source_hash)" ]
}

# Cheap check for every popup open: the binary exists and no source file was
# modified since it was built (or last verified). When this fails, callers
# fall back to binary_current, which hashes every source file.
binary_unchanged() {
	[ -x "$BINARY" ] && [ -f "$BUILT_HASH_FILE" ] &&
		[ -z "$(find "$SOURCE_DIR" -type f -newer "$BUILT_HASH_FILE" -print -quit)" ]
}

build_running() {
	[ -d "$BUILD_LOCK" ]
}
