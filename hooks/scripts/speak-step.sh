#!/usr/bin/env bash
# PostToolUse hook: speaks a short description of the tool action.
# Receives hook JSON on stdin with tool_name and tool_input.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read hook input
HOOK_INPUT=$(cat)

TOOL_NAME=$(printf '%s\n' "$HOOK_INPUT" | jq -r '.tool_name // ""')
TOOL_INPUT=$(printf '%s\n' "$HOOK_INPUT" | jq -r '.tool_input // ""')

if [[ -z "$TOOL_NAME" ]]; then
    exit 0
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
        if [[ -f /tmp/claude-speak-daemon.pid ]]; then
            pid=$(cat /tmp/claude-speak-daemon.pid 2>/dev/null || echo "")
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
