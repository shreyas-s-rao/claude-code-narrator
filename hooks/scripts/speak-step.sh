#!/usr/bin/env bash
# PostToolUse hook: speaks a short description of the tool action.
# Receives hook JSON on stdin with tool_name and tool_input.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read hook input
HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""')
TOOL_INPUT=$(echo "$HOOK_INPUT" | jq -r '.tool_input // ""')

if [[ -z "$TOOL_NAME" ]]; then
    exit 0
fi

# Generate description based on tool name
case "$TOOL_NAME" in
    Read)
        file_path=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null || echo "")
        if [[ -n "$file_path" ]]; then
            desc="Reading file $(basename "$file_path")"
        else
            desc="Reading a file"
        fi
        ;;
    Write)
        file_path=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null || echo "")
        if [[ -n "$file_path" ]]; then
            desc="Writing file $(basename "$file_path")"
        else
            desc="Writing a file"
        fi
        ;;
    Edit|MultiEdit)
        file_path=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null || echo "")
        if [[ -n "$file_path" ]]; then
            desc="Editing file $(basename "$file_path")"
        else
            desc="Editing a file"
        fi
        ;;
    Bash)
        command=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null || echo "")
        if [[ -n "$command" ]]; then
            # Extract just the program name and subcommand (first 2 non-flag words).
            # e.g. "git log --oneline -3" → "git log"
            #      "python3 -m pip install kokoro" → "python3 pip"
            #      "npm install --save-dev foo" → "npm install"
            words=()
            for word in $command; do
                [[ ${#words[@]} -ge 2 ]] && break
                [[ "$word" == -* ]] && continue
                words+=("$word")
            done
            # Commands without subcommands — only speak the program name.
            case "${words[0]:-}" in
                ls|cat|rm|cp|mv|mkdir|rmdir|touch|echo|printf|head|tail|sed|awk|grep|find|sort|wc|chmod|chown|kill|pkill|sleep|curl|wget|which|env|export|source|cd|pwd|date|whoami|hostname|uname|df|du|tar|zip|unzip|man|less|more|diff|patch|xargs|tee|tr|cut|ln|test|true|false|time|nohup|timeout|mkfifo)
                    words=("${words[0]}")
                    ;;
            esac
            if [[ ${#words[@]} -gt 0 ]]; then
                desc="Running ${words[*]}"
            else
                desc="Running a command"
            fi
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

echo "$desc" | bash "$SCRIPT_DIR/speak.sh"
