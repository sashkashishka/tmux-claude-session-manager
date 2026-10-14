#!/usr/bin/env bash
# Installs (or updates) the bundled Claude Code plugin csm-notify, which shows
# macOS notifications when a Claude session needs input or has finished.
# Without Claude Code it only warns: the tmux plugin works either way.

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

MARKETPLACE="tmux-claude-session-manager"
PLUGIN="csm-notify@$MARKETPLACE"
LOG="$PLUGIN_DIR/claude-plugin.log"
STATE="$BUILD_ROOT/claude-plugin.sha"

# Claude Code's installer puts it in ~/.local/bin; Homebrew is already on PATH.
export PATH="$HOME/.local/bin:$HOME/.claude/local:$PATH"

# A short, non-blocking message: tmux shows it for display-time, then it's gone.
warn() {
	echo "claude-session-manager: $*" >>"$LOG"
	echo "claude-session-manager: $*" >&2
	tmux display-message "claude-session-manager: $*" 2>/dev/null
}

# Hash of the Claude plugin sources, so a change reinstalls it.
plugin_hash() {
	(cd "$PLUGIN_DIR" && find .claude-plugin claude-plugin -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum | shasum | cut -d' ' -f1)
}

hash="$(plugin_hash)"
[ "$(cat "$STATE" 2>/dev/null)" = "$hash" ] && exit 0

if ! command -v claude >/dev/null; then
	warn "Claude Code not found, skipping its notifications plugin"
	exit 0
fi

: >"$LOG"
{
	# Adding fails when the marketplace is already known: refresh it instead.
	claude plugin marketplace add "$PLUGIN_DIR" --scope user ||
		claude plugin marketplace update "$MARKETPLACE"

	if claude plugin list --json | grep -q "\"$PLUGIN\""; then
		claude plugin update "$PLUGIN" --scope user
	else
		claude plugin install "$PLUGIN" --scope user
	fi
} >>"$LOG" 2>&1 || {
	warn "installing its Claude Code plugin failed, see $LOG"
	exit 0
}

mkdir -p "$BUILD_ROOT"
echo "$hash" >"$STATE"
tmux display-message "claude-session-manager: Claude Code notifications installed (new Claude sessions pick them up)" 2>/dev/null
exit 0
