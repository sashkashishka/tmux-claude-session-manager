package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// claudeRecord is the per-process file a running Claude Code keeps in
// ~/.claude/sessions/<pid>.json. It records the tmux pane the process runs in,
// whether it is busy or idle, and when that status last changed.
type claudeRecord struct {
	PID             int    `json:"pid"`
	Tmux            string `json:"tmux"` // "session:@window.%pane"
	Status          string `json:"status"`
	StatusUpdatedAt int64  `json:"statusUpdatedAt"` // unix ms
}

func (r claudeRecord) paneID() string {
	if i := strings.LastIndex(r.Tmux, "."); i >= 0 {
		return r.Tmux[i+1:]
	}
	return ""
}

func (r claudeRecord) busy() bool {
	return r.Status == "busy"
}

func (r claudeRecord) statusChangedAt() time.Time {
	if r.StatusUpdatedAt <= 0 {
		return time.Time{}
	}
	return time.UnixMilli(r.StatusUpdatedAt)
}

// claudeConfigDir is where Claude Code keeps its state: $CLAUDE_CONFIG_DIR, or ~/.claude.
func claudeConfigDir() string {
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		return dir
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".claude")
}

// loadClaudeRecords reads every session record, grouped by tmux pane ID.
// Missing or unreadable records are skipped: they only cost the sort order
// and the busy hint, never a session row.
func loadClaudeRecords() map[string][]claudeRecord {
	records := map[string][]claudeRecord{}
	dir := filepath.Join(claudeConfigDir(), "sessions")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return records
	}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		data, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			continue
		}
		var r claudeRecord
		if json.Unmarshal(data, &r) != nil || r.PID <= 0 {
			continue
		}
		if pane := r.paneID(); pane != "" {
			records[pane] = append(records[pane], r)
		}
	}
	return records
}

// recordForPane finds the record of the Claude running in a pane. Pane IDs
// repeat across tmux servers, so a record only matches when its process lives
// in the pane's process tree.
func recordForPane(records map[string][]claudeRecord, tree *procTree, paneID string, panePID int) (claudeRecord, bool) {
	for _, r := range records[paneID] {
		if tree.contains(panePID, r.PID) {
			return r, true
		}
	}
	return claudeRecord{}, false
}

// contains reports whether pid is root or one of its descendants.
func (t *procTree) contains(root, pid int) bool {
	seen := map[int]bool{}
	stack := []int{root}
	for len(stack) > 0 {
		p := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if p == pid {
			return true
		}
		if seen[p] {
			continue // guard against malformed (cyclic) snapshots
		}
		seen[p] = true
		stack = append(stack, t.children[p]...)
	}
	return false
}
