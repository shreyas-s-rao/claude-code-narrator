#!/usr/bin/env bash
# Stop hook: speaks a summary of the last assistant response.
# Receives hook JSON on stdin with last_assistant_message.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read hook input
HOOK_INPUT=$(cat)

# Extract cwd for per-directory config
export NARRATOR_CWD=$(printf '%s\n' "$HOOK_INPUT" | jq -r '.cwd // ""')

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
    # Normal mode: first ~1000 chars, ending at sentence boundary
    if [[ ${#CLEANED} -le 1000 ]]; then
        SUMMARY="$CLEANED"
    else
        # Take first 1050 chars, find last sentence boundary (. ! ?) within that
        TRIMMED=$(printf '%s' "$CLEANED" | cut -c1-1050)
        # Use awk to find the last sentence-ending punctuation followed by a space or EOL
        SUMMARY=$(printf '%s' "$TRIMMED" | awk '{
            s = s (NR>1 ? " " : "") $0
        }
        END {
            # Find last sentence boundary within 1000 chars
            best = 0
            for (i = 1; i <= length(s) && i <= 1000; i++) {
                c = substr(s, i, 1)
                if (c == "." || c == "!" || c == "?") {
                    # Check next char is space, newline, or end of string
                    if (i == length(s) || substr(s, i+1, 1) == " " || substr(s, i+1, 1) == "\n") {
                        best = i
                    }
                }
            }
            if (best > 0) {
                print substr(s, 1, best)
            } else {
                # No sentence boundary — cut at word boundary
                t = substr(s, 1, 1000)
                sub(/[[:space:]][^[:space:]]*$/, "", t)
                print t "..."
            }
        }')
    fi
    printf '%s\n' "$SUMMARY" | bash "$SCRIPT_DIR/speak.sh"
fi
