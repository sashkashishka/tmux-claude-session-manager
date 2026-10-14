# Upstream

[atbender/claude-session-manager](https://github.com/atbender/claude-session-manager), commit `b3637cf` (2026-09-15), MIT. `csm.png` (the README screenshot) is left out.

## Changes

1. **Working status from the footer** (`main.go`, `main_test.go`). Upstream marks a session Working only when its pane title starts with a Braille spinner. Claude Code 2.1.x keeps the `✳` title while working, so every session showed Idle. Sessions with a `✳` title are now Working when the screen below the last `❯` prompt shows `esc to interrupt`. The spinner check is kept for versions that still animate the title.
2. **Most recently active first** (`records.go`, `main.go`, `main_test.go`). Live sessions are sorted by when Claude last switched between busy and idle, newest first, instead of by tmux session name. The time comes from Claude Code's per-process records in `~/.claude/sessions/<pid>.json` (`statusUpdatedAt`, honouring `$CLAUDE_CONFIG_DIR`), matched to a pane by its pane ID and by the record's process running in that pane, since pane IDs repeat across tmux servers. A record's `busy` status also counts as Working; a permission prompt on screen still shows as Waiting. Sessions without a record go last, by name.
3. **Shortcut keys past row 9** (`main.go`, `README.md`, `main_test.go`). Upstream labels and selects rows `1`–`9` only. Rows 10 and on now get `0`, then the letters csm doesn't already use (`a`–`z` without `j k n q x y`): 30 one-key shortcuts in all. As before they open the row at once and are off while searching.

Otherwise csm is unmodified: it already scans tmux off the input path (Bubble Tea commands), captures panes in parallel, and reads status from pane titles first.
