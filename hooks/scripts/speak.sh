#!/usr/bin/env bash
# Speech enqueuer. Accepts text and writes it to the FIFO for the daemon to speak.
# Usage: speak.sh [--force] [text]
# If no text argument, reads from stdin.
# --force bypasses the enabled check (for /narrator:speak).

set -euo pipefail

FIFO="/tmp/claude-speak-fifo"
PID_FILE="/tmp/claude-speak-daemon.pid"
STATE_FILE="/tmp/claude-narrator-state"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORCE=false

# Parse arguments
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
    shift
fi

# Get text from argument or stdin
if [[ $# -gt 0 ]]; then
    text="$*"
else
    text="$(cat)"
fi

# Skip if text is empty/whitespace
if [[ -z "${text// /}" ]]; then
    exit 0
fi

# Replace dots in filename-like words (e.g. "settings.json" → "settings dot json")
# so TTS doesn't treat the dot as a sentence boundary.
# Requires 2+ chars before the dot to avoid mangling abbreviations like "e.g." or "i.e."
# Second pass catches residual chained segments (e.g. "dot d.ts" from "types.d.ts").
text=$(echo "$text" | sed -E 's/([a-zA-Z0-9_-]{2,})\.([a-zA-Z]{1,10})/\1 dot \2/g; s/(dot [a-zA-Z0-9_-]+)\.([a-zA-Z]{1,10})/\1 dot \2/g')

# Check enabled state (unless --force)
if [[ "$FORCE" != "true" ]]; then
    enabled="false"
    if [[ -f "$STATE_FILE" ]]; then
        enabled=$(grep -m1 '^enabled=' "$STATE_FILE" 2>/dev/null | cut -d= -f2 || echo "false")
    fi
    if [[ "$enabled" != "true" ]]; then
        exit 0
    fi
fi

# Start daemon if not running
daemon_running=false
if [[ -f "$PID_FILE" ]]; then
    pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        daemon_running=true
    fi
fi

if [[ "$daemon_running" != "true" ]]; then
    # Create FIFO if it doesn't exist
    mkfifo "$FIFO" 2>/dev/null || true
    # Start daemon in background (loads TTS pipeline — takes ~10s on first start)
    nohup bash "$SCRIPT_DIR/speak-daemon.sh" >/dev/null 2>&1 &
    disown
    # Wait for daemon to open the FIFO (pipeline loading takes time)
    for i in $(seq 1 30); do
        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
            break
        fi
        sleep 0.5
    done
fi

# Write text to FIFO (with timeout in case daemon died)
if command -v timeout >/dev/null 2>&1; then
    timeout 5 bash -c "printf '%s\n' $(printf '%q' "$text") > '$FIFO'" 2>/dev/null || true
else
    printf '%s\n' "$text" > "$FIFO" &
    write_pid=$!
    sleep 5 && kill "$write_pid" 2>/dev/null &
    wait "$write_pid" 2>/dev/null || true
fi
