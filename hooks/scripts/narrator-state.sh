#!/usr/bin/env bash
# Shared state resolution, sourced by speak.sh and the hook scripts.
# Reads a setting from the local state file (<NARRATOR_CWD>/.claude-code-narrator/config),
# falling back to the global one (~/.claude-code-narrator/config).

NARRATOR_DIR="$HOME/.claude-code-narrator"
STATE_FILE="$NARRATOR_DIR/config"
LOCAL_STATE_FILE="${NARRATOR_CWD:+${NARRATOR_CWD}/.claude-code-narrator/config}"

# Usage: resolve_state <key> <default>
# Values are returned as written; callers that match fixed values normalize
# them with normalize_value.
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

# Lowercase and strip whitespace (including a CR from CRLF line endings).
normalize_value() {
    printf '%s' "$1" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'
}

# What gets spoken (see README "What Gets Spoken"):
#   minimal — tool descriptions only
#   normal  — tool descriptions + final response
#   verbose — tool descriptions + text between tool calls + final response + notifications (default)
#   final   — final response only
narrator_verbosity() {
    local v
    v=$(normalize_value "$(resolve_state "verbosity" "verbose")")
    case "$v" in
        minimal|normal|verbose|final) printf '%s' "$v" ;;
        *) printf 'verbose' ;;
    esac
}

# How much of the final response is spoken: summary (default, ~1000 chars) or full.
narrator_length() {
    local v
    v=$(normalize_value "$(resolve_state "length" "summary")")
    case "$v" in
        summary|full) printf '%s' "$v" ;;
        *) printf 'summary' ;;
    esac
}
