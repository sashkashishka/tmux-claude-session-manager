# tmux-claude-session-manager

TPM plugin bundling [claude-session-manager](https://github.com/atbender/claude-session-manager) (`csm`): see every Claude Code session (working / waiting / idle) in a popup, jump to one, resume a recent project or start a new session.

On load it:

- binds `prefix + Y` to open csm in a popup;
- builds the bundled source (`vendor/claude-session-manager`) in the background if the binary is missing or older than the source;
- installs the bundled Claude Code plugin `csm-notify` (see [Notifications](#notifications)).

Pressing the binding before the build finishes shows its progress, then opens csm.

## Requirements

- tmux ≥ 3.2 (for `display-popup`)
- Go ≥ 1.24 to build csm. It isn't installed for you: get it from [go.dev/dl](https://go.dev/dl) or with `brew install go`. Without it the plugin shows an error. The first build downloads csm's Go modules.

## Install

```tmux
set -g @plugin 'sashkashishka/tmux-claude-session-manager'
```

Then `prefix + I`.

## Options

| Option | Default | |
|---|---|---|
| `@csm-key` | `Y` | key after the prefix |
| `@csm-width` | `80%` | popup width (cells or `%`) |
| `@csm-height` | `80%` | popup height (cells or `%`) |
| `@csm-claude-args` | | extra flags for the Claude sessions csm starts, e.g. `--dangerously-skip-permissions` |
| `@csm-auto-build` | `on` | build csm when the plugin loads |
| `@csm-claude-plugin` | `on` | install the `csm-notify` Claude Code plugin when the plugin loads |

The popup is opened for the client that pressed the key, so with several clients attached csm switches that one.

## Notifications

The repo is also a one-plugin Claude Code marketplace. Its plugin, `csm-notify` (`claude-plugin/`), shows a macOS notification when a Claude session:

- needs you: a permission prompt, plan approval or question is pending (idle reminders are skipped);
- has finished its turn.

Title is the tmux `session:index window`, subtitle the pane's path, body the message.

No notification is shown while you're looking at that session: a tmux client whose terminal has focus is showing that Claude's pane. This relies on [terminal focus tracking](#terminal-focus-tracking). Set `CSM_NOTIFY_WHEN_WATCHING=1` to always notify.

When the tmux plugin loads, it runs `claude plugin marketplace add` and `claude plugin install csm-notify@tmux-claude-session-manager` in the background, and reinstalls when `claude-plugin/` changes (bump its `version` in `plugin.json` too). If Claude Code isn't found it only shows a short tmux message; output goes to `claude-plugin.log`. Claude sessions started before the install pick it up after a restart.

By hand, e.g. without the tmux plugin: `/plugin install csm-notify --marketplace sashkashishka/tmux-claude-session-manager`. To remove: `claude plugin uninstall csm-notify@tmux-claude-session-manager` and set `@csm-claude-plugin off`.

Debugging: set `CSM_NOTIFY_LOG` (a file path) in the environment Claude runs in to log every hook payload; `CSM_NOTIFY_DRY_RUN=1` prints the notification instead of showing it.

## Terminal focus tracking

tmux can only tell whether you're looking at a pane if the terminal tells it when its window gains or loses focus. Both sides have to be on:

1. **tmux** asks the terminal for focus reports:

   ```tmux
   set -g focus-events on
   ```

2. **iTerm2** has to send them. Focus reporting is an iTerm2 setting: Settings → Advanced, search "focus reporting", set it to Yes. Or:

   ```sh
   defaults write com.googlecode.iterm2 FocusReportingEnabled -bool true
   ```

   Then quit iTerm2 (⌘Q) and reattach (`tmux attach`): iTerm2 reads the setting at launch, and tmux only requests focus reports when a client attaches. tmux sessions keep running meanwhile.

Check it: run this, then switch to another app and back within 10 seconds. The flag should flip between `focused` and not.

```sh
for i in $(seq 50); do tmux list-clients -F '#{client_termtype} #{client_flags}'; sleep 0.2; done | uniq
```

If it never changes, focus reports aren't arriving. tmux then keeps whatever focus state it last had, which can be `focused` forever, and `csm-notify` would skip notifications for the pane left on screen. Fix the setting above, or set `CSM_NOTIFY_WHEN_WATCHING=1`.

Other terminals need the same support: Ghostty, WezTerm, kitty and Alacritty answer focus-report requests (`CSI ? 1004 h`) out of the box. With focus reporting enabled, programs inside tmux that ask for it receive focus events too (e.g. Neovim's `FocusGained` / `autoread`).

## Keys in csm

`j`/`k` move, `1`–`9`, `0` and the letters shown next to rows pick a row, `Enter` switches (or resumes a closed project, after `y/n`), `n` starts a new session in the row's folder, `/` searches, `x` kills a session, `q`/`Esc` quits. See [`vendor/claude-session-manager/README.md`](vendor/claude-session-manager/README.md).

## Development

- Edit `vendor/claude-session-manager`; the next plugin load or `prefix + Y` rebuilds it (changes are detected by modification time, then confirmed by hashing the source). Build output: `build.log`.
- To pull a newer upstream, replace `vendor/claude-session-manager` with the new release and re-apply the changes listed in `UPSTREAM.md`.
- Removing the plugin dir removes the binary too (Go's module and build caches stay in their usual places).

## License

The plugin scripts are this repo's own. `vendor/claude-session-manager` is © atbender under the [MIT license](vendor/claude-session-manager/LICENSE).
