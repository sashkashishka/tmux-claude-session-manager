package main

import "testing"

func TestDetermineStatus(t *testing.T) {
	border := "──────────"
	cases := []struct {
		name    string
		content string
		want    int
	}{
		{"working footer", "output\n" + border + "\n❯ \n" + border + "\n  ⏵⏵ auto mode on · esc to interrupt\n", StatusWorking},
		{"idle footer", "output\n" + border + "\n❯ \n" + border + "\n  ? for shortcuts\n", StatusIdle},
		{"permission prompt", "Allow this command?\n❯ 1. Yes\n  2. No\nEsc to cancel\n", StatusWaiting},
		{"interrupt text above the prompt is ignored", "we discussed esc to interrupt\n" + border + "\n❯ \n" + border + "\n  ? for shortcuts\n", StatusIdle},
		{"no prompt", "loading…\n", StatusIdle},
	}
	for _, c := range cases {
		if got := determineStatus(c.content); got != c.want {
			t.Errorf("%s: got %d, want %d", c.name, got, c.want)
		}
	}
}

func TestRecordForPane(t *testing.T) {
	// pane shell 100 → claude 101; another server's pane shell 200 → claude 201
	tree := &procTree{
		children: map[int][]int{100: {101}, 200: {201}},
		comm:     map[int]string{101: "claude", 201: "claude"},
	}
	records := map[string][]claudeRecord{
		"%3": {
			{PID: 201, Tmux: "other:@1.%3", Status: "idle", StatusUpdatedAt: 1},
			{PID: 101, Tmux: "work:@4.%3", Status: "busy", StatusUpdatedAt: 2},
		},
	}
	r, ok := recordForPane(records, tree, "%3", 100)
	if !ok || r.PID != 101 || !r.busy() {
		t.Fatalf("got %+v, %v; want the busy record of pid 101", r, ok)
	}
	if _, ok := recordForPane(records, tree, "%3", 300); ok {
		t.Fatal("matched a record whose process is not in the pane")
	}
	if got := (claudeRecord{Tmux: "s:@7.%12"}).paneID(); got != "%12" {
		t.Fatalf("paneID = %q, want %%12", got)
	}
}

func TestRowKeys(t *testing.T) {
	for _, bound := range "jknqxy/" {
		if rowKeyIndex(string(bound)) >= 0 {
			t.Errorf("%q is already bound but is also a row shortcut", bound)
		}
	}
	seen := map[rune]bool{}
	for _, k := range rowKeys {
		if seen[k] {
			t.Errorf("duplicate row key %q", k)
		}
		seen[k] = true
	}
	if rowKeyIndex("1") != 0 || rowKeyIndex("9") != 8 || rowKeyIndex("0") != 9 || rowKeyIndex("a") != 10 {
		t.Error("digits must keep rows 1–9, then 0 is row 10 and a row 11")
	}
	if rowKeyIndex("ctrl+a") != -1 || rowKeyIndex("A") != -1 {
		t.Error("only single lowercase keys are shortcuts")
	}
}
