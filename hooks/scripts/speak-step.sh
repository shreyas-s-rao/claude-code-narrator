#!/usr/bin/env bash
# PostToolUse hook: speaks a short description of the tool action.
# Also narrates any preceding text block from the transcript that would
# otherwise be lost (text blocks between tool calls aren't sent to any hook).
# Receives hook JSON on stdin with tool_name, tool_input, tool_use_id, transcript_path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read hook input
HOOK_INPUT=$(cat)

TOOL_NAME=$(printf '%s\n' "$HOOK_INPUT" | jq -r '.tool_name // ""')
TOOL_INPUT=$(printf '%s\n' "$HOOK_INPUT" | jq -r '.tool_input // ""')
TOOL_USE_ID=$(printf '%s\n' "$HOOK_INPUT" | jq -r '.tool_use_id // ""')
TRANSCRIPT_PATH=$(printf '%s\n' "$HOOK_INPUT" | jq -r '.transcript_path // ""')

if [[ -z "$TOOL_NAME" ]]; then
    exit 0
fi

# Narrate any preceding text block from the transcript.
# When Claude outputs text → tool_use, the text block has no hook.
# We find the last unspoken text block in the transcript and speak it.
SPOKEN_FILE="$HOME/.claude-code-narrator/last-spoken"
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
    preceding_text=$(tail -60 "$TRANSCRIPT_PATH" | SPOKEN_FILE="$SPOKEN_FILE" python3 -c "
import sys, json, os
spoken_file = os.environ.get('SPOKEN_FILE', '')
last_spoken = ''
if spoken_file:
    try:
        with open(spoken_file) as f:
            last_spoken = f.read().strip()
    except FileNotFoundError:
        pass
lines = []
for line in sys.stdin:
    line = line.strip()
    if line:
        lines.append(json.loads(line))
# Find the last user entry — everything after it is the current assistant turn
last_user_idx = -1
for i, entry in enumerate(lines):
    if entry.get('type') == 'user':
        last_user_idx = i
# If no user entry found, we can't scope to current turn — skip
if last_user_idx < 0:
    sys.exit(0)
current_turn = lines[last_user_idx + 1:]
# Find the last text block in the current turn
last_text = ''
last_text_id = ''
for entry in current_turn:
    if entry.get('type') != 'assistant':
        continue
    content = entry.get('message', {}).get('content', [])
    msg_id = entry.get('message', {}).get('id', '')
    for block in content:
        if block.get('type') == 'text' and block.get('text', '').strip():
            last_text = block['text'].strip()
            last_text_id = msg_id + ':' + block.get('text', '')[:20]
if last_text and last_text_id != last_spoken:
    if spoken_file:
        with open(spoken_file, 'w') as f:
            f.write(last_text_id)
    print(last_text)
" 2>/dev/null || echo "")
    if [[ -n "$preceding_text" ]]; then
        printf '%s\n' "$preceding_text" | bash "$SCRIPT_DIR/speak.sh"
    fi
fi

# Generate description based on tool name
case "$TOOL_NAME" in
    Read)
        file_path=$(printf '%s\n' "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null || echo "")
        if [[ -n "$file_path" ]]; then
            desc="Reading file $(basename "$file_path")"
        else
            desc="Reading a file"
        fi
        ;;
    Write)
        file_path=$(printf '%s\n' "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null || echo "")
        if [[ -n "$file_path" ]]; then
            desc="Writing file $(basename "$file_path")"
        else
            desc="Writing a file"
        fi
        ;;
    Edit|MultiEdit)
        file_path=$(printf '%s\n' "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null || echo "")
        if [[ -n "$file_path" ]]; then
            desc="Editing file $(basename "$file_path")"
        else
            desc="Editing a file"
        fi
        ;;
    Bash)
        command=$(printf '%s\n' "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null || echo "")
        if [[ -n "$command" ]]; then
            # shellcheck source=hooks/scripts/extract-command.sh
            source "$SCRIPT_DIR/extract-command.sh"
            extract_command_desc "$command"
            desc="$COMMAND_DESC"
        else
            desc="Running a command"
        fi
        ;;
    Grep)
        desc="Searching codebase"
        ;;
    Glob)
        desc="Finding files"
        ;;
    WebFetch|WebSearch)
        desc="Searching the web"
        ;;
    AskUserQuestion)
        # User just interacted — hush any queued/playing speech and exit.
        if [[ -f "$HOME/.claude-code-narrator/daemon.pid" ]]; then
            pid=$(cat "$HOME/.claude-code-narrator/daemon.pid" 2>/dev/null || echo "")
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                kill -USR1 "$pid" 2>/dev/null || true
            fi
        fi
        exit 0
        ;;
    Agent|Skill)
        desc="Delegating to sub-agent"
        ;;
    mcp__*)
        # MCP tools: extract a cleaner name
        clean_name="${TOOL_NAME#mcp__}"
        desc="Using MCP tool $clean_name"
        ;;
    *)
        desc="Using $TOOL_NAME"
        ;;
esac

printf '%s\n' "$desc" | bash "$SCRIPT_DIR/speak.sh"
