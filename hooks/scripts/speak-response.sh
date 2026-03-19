#!/usr/bin/env bash
# Stop hook: speaks a summary of the last assistant response.
# Receives hook JSON on stdin with last_assistant_message.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read hook input
HOOK_INPUT=$(cat)

# Extract the assistant message directly from the hook payload
LAST_TEXT=$(printf '%s\n' "$HOOK_INPUT" | jq -r '.last_assistant_message // ""')

if [[ -z "$LAST_TEXT" ]]; then
    exit 0
fi

# Strip markdown formatting
clean_markdown() {
    awk '
        /^```/ { fence = !fence; next }
        fence { next }
        { print }
    ' | sed -E '
        s/`([^`]+)`/\1/g
        s/\[([^]]+)\]\([^)]+\)/\1/g
        s/^#{1,6} //
        s/\*\*([^*]+)\*\*/\1/g
        s/\*([^*]+)\*/\1/g
        s/^---+$//
        s/^[[:space:]]*$//
        /^$/d
    '
}

CLEANED=$(printf '%s\n' "$LAST_TEXT" | clean_markdown)

if [[ -z "$CLEANED" ]]; then
    exit 0
fi

# Check if in plan mode
PERMISSION_MODE=$(printf '%s\n' "$HOOK_INPUT" | jq -r '.permission_mode // ""')

if [[ "$PERMISSION_MODE" == "plan" ]]; then
    # Plan mode: speak full cleaned text
    printf '%s\n' "$CLEANED" | bash "$SCRIPT_DIR/speak.sh"
else
    # Normal mode: first ~300 chars, ending at sentence boundary
    if [[ ${#CLEANED} -le 300 ]]; then
        SUMMARY="$CLEANED"
    else
        # Try to find sentence boundary (. ! ?) within first 300 chars
        SUMMARY=$(printf '%s\n' "$CLEANED" | cut -c1-350 | sed -E 's/([.!?])[[:space:]].*/\1/' | cut -c1-300)
        # If no sentence boundary found (same length as input), cut at word boundary
        if [[ ${#SUMMARY} -ge 299 ]]; then
            SUMMARY=$(printf '%s\n' "$CLEANED" | cut -c1-300 | sed 's/[[:space:]][^[:space:]]*$//')
            SUMMARY="${SUMMARY}..."
        fi
    fi
    printf '%s\n' "$SUMMARY" | bash "$SCRIPT_DIR/speak.sh"
fi
