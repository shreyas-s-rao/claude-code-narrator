#!/usr/bin/env bash
# Shared helper: extracts a human-friendly description from a Bash command string.
# Usage: source this file, then call extract_command_desc "$command"
# Sets the variable COMMAND_DESC.

extract_command_desc() {
    local command="$1"
    local words=()
    local skip_next=false
    for word in $command; do
        [[ ${#words[@]} -ge 2 ]] && break
        if [[ "$skip_next" == "true" ]]; then
            skip_next=false
            continue
        fi
        # Long flags with = (e.g. --config=/path) are self-contained
        if [[ "$word" == --*=* ]]; then
            continue
        fi
        # Long flags that take a value argument (next word)
        if [[ "$word" == --* ]]; then
            skip_next=true
            continue
        fi
        # python -m <module> — treat the module name as a subcommand, not a flag value
        if [[ "$word" == "-m" && ("${words[0]:-}" == python* || "${words[0]:-}" == python3) ]]; then
            continue
        fi
        # Short flags: single-letter flags (e.g. -C, -m) likely take a value argument,
        # so skip the next word. Multi-letter short flags (e.g. -la, -rf) are combined
        # booleans — just skip the flag itself.
        if [[ "$word" == -? ]]; then
            skip_next=true
            continue
        fi
        if [[ "$word" == -* ]]; then
            continue
        fi
        words+=("$word")
    done
    # Commands without subcommands — only speak the program name.
    case "${words[0]:-}" in
        ls|cat|rm|cp|mv|mkdir|rmdir|touch|echo|printf|head|tail|sed|awk|grep|find|sort|wc|chmod|chown|kill|pkill|sleep|curl|wget|which|env|export|source|cd|pwd|date|whoami|hostname|uname|df|du|tar|zip|unzip|man|less|more|diff|patch|xargs|tee|tr|cut|ln|test|true|false|time|nohup|timeout|mkfifo|rsync|scp)
            words=("${words[0]}")
            ;;
    esac
    if [[ ${#words[@]} -gt 0 ]]; then
        COMMAND_DESC="Running ${words[*]}."
    else
        COMMAND_DESC="Running a command."
    fi
}
