#!/usr/bin/env bash
# Notification hook: speaks notification messages aloud.
# Receives hook JSON on stdin with message and title.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read hook input
HOOK_INPUT=$(cat)

# Extract cwd for per-directory config
export NARRATOR_CWD=$(printf '%s\n' "$HOOK_INPUT" | jq -r '.cwd // ""')

MESSAGE=$(echo "$HOOK_INPUT" | jq -r '.message // ""')
TITLE=$(echo "$HOOK_INPUT" | jq -r '.title // ""')

# Build speech text
if [[ -n "$TITLE" && -n "$MESSAGE" ]]; then
    text="$TITLE: $MESSAGE"
elif [[ -n "$MESSAGE" ]]; then
    text="$MESSAGE"
elif [[ -n "$TITLE" ]]; then
    text="$TITLE"
else
    text="Notification from Claude"
fi

# Truncate to 200 chars if needed
if [[ ${#text} -gt 200 ]]; then
    text="${text:0:200}..."
fi

echo "$text" | bash "$SCRIPT_DIR/speak.sh"
