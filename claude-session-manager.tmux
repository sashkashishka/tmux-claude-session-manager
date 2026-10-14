#!/usr/bin/env bash
# TPM entry point: binds the popup key and builds csm in the background if needed.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/scripts/helpers.sh"

key="$(get_opt @csm-key Y)"
width="$(get_opt @csm-width 80%)"
height="$(get_opt @csm-height 80%)"
claude_args="$(get_opt @csm-claude-args "")"

# csm switches the client named in CSM_TMUX_CLIENT, so with several clients
# attached it moves the one that opened the popup. #{client_name} doesn't
# expand inside display-popup's command, hence the run-shell wrapper.
popup="tmux display-popup -c '#{client_name}' -E -w '$width' -h '$height' -e CSM_TMUX_CLIENT='#{client_name}'"
if [ -n "$claude_args" ]; then
	# Extra flags for the Claude sessions csm spawns
	popup="$popup -e CSM_CLAUDE_ARGS='$claude_args'"
fi
tmux bind-key "$key" run-shell "$popup '$CURRENT_DIR/scripts/launch.sh'"

# Claude Code plugin with the notification hooks; warns and moves on without Claude Code.
if [ "$(get_opt @csm-claude-plugin on)" = on ]; then
	tmux run-shell -b "$CURRENT_DIR/scripts/install-claude-plugin.sh"
fi

if [ "$(get_opt @csm-auto-build on)" = on ] && ! binary_current; then
	tmux run-shell -b "$CURRENT_DIR/scripts/build.sh"
fi
