#!/usr/bin/env bash
# Speech enqueuer. Accepts text and writes it to the FIFO for the daemon to speak.
# Usage: speak.sh [--force] [text]
# If no text argument, reads from stdin.
# --force bypasses the enabled check (for /narrator:speak).

set -euo pipefail

NARRATOR_DIR="$HOME/.claude-code-narrator"
mkdir -p "$NARRATOR_DIR"
FIFO="$NARRATOR_DIR/fifo"
PID_FILE="$NARRATOR_DIR/daemon.pid"
STATE_FILE="$NARRATOR_DIR/config"
LOCAL_STATE_FILE="${NARRATOR_CWD:+${NARRATOR_CWD}/.claude-code-narrator/config}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read a setting from the local state file, falling back to global state.
# Usage: resolve_state <key> <default>
resolve_state() {
    local key="$1" default="$2" val=""
    # Try local state first
    if [[ -n "${LOCAL_STATE_FILE:-}" && -f "$LOCAL_STATE_FILE" ]]; then
        val=$(grep -m1 "^${key}=" "$LOCAL_STATE_FILE" 2>/dev/null | cut -d= -f2 || echo "")
    fi
    # Fall back to global state
    if [[ -z "$val" && -f "$STATE_FILE" ]]; then
        val=$(grep -m1 "^${key}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2 || echo "")
    fi
    printf '%s' "${val:-$default}"
}

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
if [[ -z "${text//[[:space:]]/}" ]]; then
    exit 0
fi

# ── TTS-friendly text replacements ──
# Make symbols, markdown, and abbreviations sound natural when spoken aloud.

# Abbreviations (before dot replacement to avoid "e dot g")
text="${text//e.g./for example}"
text="${text//i.e./that is}"

# Replace dots in filename-like words (e.g. "settings.json" → "settings dot json")
# so TTS doesn't treat the dot as a sentence boundary.
# Requires 2+ chars before the dot to avoid mangling abbreviations.
# Second pass catches residual chained segments (e.g. "dot d.ts" from "types.d.ts").
text=$(printf '%s\n' "$text" | sed -E 's/([a-zA-Z0-9_-]{2,})\.([a-zA-Z]{1,10})/\1 dot \2/g; s/(dot [a-zA-Z0-9_-]+)\.([a-zA-Z]{1,10})/\1 dot \2/g')

# Arrows and symbols
text="${text//→/ to }"
text="${text//=>/ arrow }"
text="${text//->/ arrow }"
text="${text//<=/ less or equal }"
text="${text//>=/ greater or equal }"
text="${text//!=/ not equal }"
text="${text//==/ equals }"
text="${text//&&/ and }"
text="${text//||/ or }"

# Paths and env vars
text="${text//\~\//home slash }"
text="${text//\$HOME/home}"
text="${text//\/dev\/null/dev null}"

# Shorthand
text="${text//w\/o /without }"
text="${text// w\// with }"

# Technical terms
text="${text//stderr/standard error}"
text="${text//stdout/standard output}"

# Markdown noise — strip backticks, bold markers, heading markers
text=$(printf '%s\n' "$text" | sed -E 's/`//g; s/\*\*//g; s/^#{1,6} //g')

# Ellipsis — collapse to single space (avoids TTS stutter)
text="${text//.../ }"

# Pipe — replace with comma for natural pause (only freestanding pipes)
text=$(printf '%s\n' "$text" | sed -E 's/ \| /, /g')

# Check enabled state (unless --force)
if [[ "$FORCE" != "true" ]]; then
    enabled=$(resolve_state "enabled" "false")
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

LOCK_DIR="$NARRATOR_DIR/daemon.lock"
if [[ "$daemon_running" != "true" ]]; then
    # Clean up stale lock from a previous daemon that was killed externally
    if [[ -d "$LOCK_DIR" ]]; then
        rmdir "$LOCK_DIR" 2>/dev/null || true
    fi
    # Use mkdir as an atomic lock to prevent concurrent daemon starts
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
        # Re-check after acquiring lock — another invocation may have started the daemon
        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
            rmdir "$LOCK_DIR" 2>/dev/null || true
        else
            # Ensure FIFO exists and is a named pipe (not a regular file)
            if [[ -e "$FIFO" && ! -p "$FIFO" ]]; then
                rm -f "$FIFO"
            fi
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
            rmdir "$LOCK_DIR" 2>/dev/null || true
        fi
    else
        # Another invocation holds the lock — wait for daemon to become ready
        for i in $(seq 1 30); do
            if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
                break
            fi
            sleep 0.5
        done
    fi
fi

# Resolve voice and speed for this utterance
voice=$(resolve_state "voice" "af_heart")
speed=$(resolve_state "speed" "1.1")

# Build JSON message with per-utterance settings
json_msg=$(printf '{"text":"%s","voice":"%s","speed":%s}' \
    "$(printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')" \
    "$voice" "$speed")

# Write JSON to FIFO (with timeout in case daemon died)
if command -v timeout >/dev/null 2>&1; then
    timeout 5 bash -c 'printf "%s\n" "$1" > "$2"' -- "$json_msg" "$FIFO" 2>/dev/null || true
else
    printf '%s\n' "$json_msg" > "$FIFO" &
    write_pid=$!
    { sleep 5; kill "$write_pid" 2>/dev/null; } &
    killer_pid=$!
    wait "$write_pid" 2>/dev/null || true
    kill "$killer_pid" 2>/dev/null; wait "$killer_pid" 2>/dev/null || true
fi
