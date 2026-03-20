#!/usr/bin/env bash
# Shared helper: extracts a human-friendly description from a Bash command string.
# Usage: source this file, then call extract_command_desc "$command"
# Sets the variable COMMAND_DESC.

extract_command_desc() {
    local command="$1"
    local words=()
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
        COMMAND_DESC="Running ${words[*]}."
    else
        COMMAND_DESC="Running a command."
    fi
}
