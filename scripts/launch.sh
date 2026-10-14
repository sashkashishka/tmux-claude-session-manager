#!/usr/bin/env bash
# Runs inside the popup: opens csm, building it first if it's missing or stale.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

if binary_unchanged; then
	exec "$BINARY"
fi

if binary_current; then
	# Sources were touched but not changed (e.g. a checkout): remember that
	# they're verified so the next open takes the cheap path again.
	touch "$BUILT_HASH_FILE"
	exec "$BINARY"
fi

if ! build_running; then
	# Started via tmux so the build survives the popup being closed.
	tmux run-shell -b "$CURRENT_DIR/build.sh"
	for _ in $(seq 30); do
		build_running && break
		sleep 0.1
	done
fi

echo "Building csm (Ctrl-C closes this; the build keeps going)."
echo
tail -n +1 -f "$BUILD_LOG" 2>/dev/null &
tail_pid=$!
while build_running; do sleep 1; done
kill "$tail_pid" 2>/dev/null

if binary_current; then
	exec "$BINARY"
fi

echo
echo "Build failed. Full log: $BUILD_LOG"
read -rsn1 -p "Press any key to close."
