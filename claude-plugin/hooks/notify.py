#!/usr/bin/env python3
"""csm-notify: macOS notification when a Claude Code session needs you or is done.

Runs for two hook events:

  Notification  a permission prompt, plan approval, or question is pending.
                Claude Code also fires it when a session has merely been idle
                for a while ("waiting for your input"); those are dropped, since
                nothing is blocked. The filter is a denylist, not an allowlist:
                an unrecognised notification still notifies, because a missed
                permission prompt costs more than one spurious banner.
  Stop          Claude has finished its turn.

Identity comes from tmux, which knows the pane's real path — the payload's cwd
is unreliable and os.getcwd() resolves to this script's directory, not the
session's.

  title     tmux `session:index window` — the address you type to jump there
  subtitle  pane path, home abbreviated to ~
  body      the notification message, or "Claude has finished"

No notification is shown while you're looking at the session: an attached
tmux client whose terminal has focus is showing this Claude's pane. That
needs tmux `focus-events on` and a terminal that reports focus (in iTerm2,
focus reporting is a setting). Set CSM_NOTIFY_WHEN_WATCHING=1 to notify anyway.

Debugging: set CSM_NOTIFY_LOG to a file path to append every payload as JSON
(including the suppressed ones). Set CSM_NOTIFY_DRY_RUN=1 to print the
AppleScript instead of showing the notification.
"""
import json
import os
import subprocess
import sys

FALLBACK_TITLE = "Claude Code"
FALLBACK_MSG = "Claude needs your input"
FINISHED_MSG = "Claude has finished"

# Notification types that don't need you to act.
QUIET_TYPES = {"idle_prompt", "auth_success"}

# Substrings marking a notification as "nothing is actually pending", for
# payloads without a notification_type. Matched case-insensitively.
IDLE_MARKERS = (
    "waiting for your input",
    "is idle",
    "idle for",
)


def applescript_str(s):
    """Escape for embedding in an AppleScript double-quoted string."""
    return s.replace("\\", "\\\\").replace('"', '\\"')


def tilde(path):
    home = os.path.expanduser("~")
    return "~" + path[len(home):] if path.startswith(home) else path


def tmux_pane_info():
    """(label, path) for the pane Claude Code runs in; (None, None) outside tmux."""
    pane = os.environ.get("TMUX_PANE")
    if not (pane and os.environ.get("TMUX")):
        return None, None
    try:
        out = subprocess.run(
            ["tmux", "display-message", "-p", "-t", pane,
             "#S:#I #W\t#{pane_current_path}"],
            capture_output=True, text=True, timeout=3,
        )
        label, _, path = out.stdout.strip().partition("\t")
        return (label or None), (path or None)
    except Exception:
        return None, None


def user_is_watching():
    """True when a tmux client with terminal focus shows this Claude's pane.

    Any doubt (outside tmux, tmux not answering) counts as not watching, so a
    notification is never lost to the check.
    """
    pane = os.environ.get("TMUX_PANE")
    if not (pane and os.environ.get("TMUX")):
        return False
    try:
        # #{pane_id} is the active pane of the window each client is showing
        out = subprocess.run(
            ["tmux", "list-clients", "-F", "#{client_flags}\t#{pane_id}"],
            capture_output=True, text=True, timeout=3,
        )
    except Exception:
        return False
    for line in out.stdout.splitlines():
        flags, _, shown_pane = line.partition("\t")
        if shown_pane == pane and "focused" in flags.split(","):
            return True
    return False


def log(record):
    path = os.environ.get("CSM_NOTIFY_LOG")
    if not path:
        return
    try:
        with open(os.path.expanduser(path), "a") as f:
            f.write(json.dumps(record) + "\n")
    except Exception:
        pass


def message_for(payload):
    """The notification body, or None when there's nothing to notify about."""
    event = payload.get("hook_event_name")

    if event == "Stop":
        # Stop hooks that keep Claude going re-enter Stop; notify only once.
        if payload.get("stop_hook_active"):
            return None
        return FINISHED_MSG

    message = (payload.get("message") or FALLBACK_MSG).strip() or FALLBACK_MSG
    if payload.get("notification_type") in QUIET_TYPES:
        return None
    lowered = message.lower()
    if any(marker in lowered for marker in IDLE_MARKERS):
        return None
    return message


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        payload = {}

    message = message_for(payload)
    watching = (
        message is not None
        and not os.environ.get("CSM_NOTIFY_WHEN_WATCHING")
        and user_is_watching()
    )
    label, pane_path = tmux_pane_info()
    log({"payload": payload, "notified": None if watching else message,
         "watching": watching, "pane_path": pane_path, "label": label})

    if message is None or watching:
        return

    where = payload.get("cwd") or pane_path
    where = tilde(where.rstrip("/")) if where else ""
    session = (payload.get("session_id") or "")[:8]

    title, subtitle = (label, where or session) if label else (where or FALLBACK_TITLE, session)

    script = 'display notification "{}" with title "{}"'.format(
        applescript_str(message), applescript_str(title)
    )
    if subtitle:
        script += ' subtitle "{}"'.format(applescript_str(subtitle))

    if os.environ.get("CSM_NOTIFY_DRY_RUN"):
        print(script)
        return

    try:
        subprocess.run(["osascript", "-e", script], timeout=5)
    except Exception:
        pass  # never fail the hook


if __name__ == "__main__":
    main()
