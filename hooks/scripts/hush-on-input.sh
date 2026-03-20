#!/usr/bin/env bash
# Auto-hush: stop current speech when the user submits input.
# Sends SIGUSR1 to the daemon, which stops audio playback but keeps the
# daemon alive so subsequent speech doesn't need a cold restart.
# Registered as a UserPromptSubmit hook.

NARRATOR_DIR="$HOME/.claude-code-narrator"
PID_FILE="$NARRATOR_DIR/daemon.pid"
STATE_FILE="$NARRATOR_DIR/config"

# Extract cwd from hook JSON for per-directory config
HOOK_INPUT=$(cat)
NARRATOR_CWD=$(printf '%s\n' "$HOOK_INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
LOCAL_STATE_FILE="${NARRATOR_CWD:+${NARRATOR_CWD}/.claude-code-narrator/config}"

# Only act if narrator is enabled (check local then global)
enabled="false"
if [[ -n "${LOCAL_STATE_FILE:-}" && -f "$LOCAL_STATE_FILE" ]]; then
    enabled=$(grep -m1 '^enabled=' "$LOCAL_STATE_FILE" 2>/dev/null | cut -d= -f2 || echo "")
fi
if [[ -z "$enabled" && -f "$STATE_FILE" ]]; then
    enabled=$(grep -m1 '^enabled=' "$STATE_FILE" 2>/dev/null | cut -d= -f2 || echo "false")
fi
[[ "$enabled" != "true" ]] && exit 0

# Send SIGUSR1 to the daemon to stop current playback (keeps daemon alive)
if [[ -f "$PID_FILE" ]]; then
    pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill -USR1 "$pid" 2>/dev/null || true
    fi
fi

# Kill any standalone kokoro-speak.py processes
pkill -f kokoro-speak.py 2>/dev/null || true
