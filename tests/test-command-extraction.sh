#!/usr/bin/env bash
# Tests for the Bash command extraction in speak-step.sh.
# Run: bash tests/test-command-extraction.sh

set -euo pipefail

PASS=0
FAIL=0

assert_eq() {
    local description="$1"
    local command="$2"
    local expected="$3"

    local actual
    actual=$(bash -c '
        command="$1"
        words=()
        for word in $command; do
            [[ ${#words[@]} -ge 2 ]] && break
            [[ "$word" == -* ]] && continue
            words+=("$word")
        done
        case "${words[0]:-}" in
            ls|cat|rm|cp|mv|mkdir|rmdir|touch|echo|printf|head|tail|sed|awk|grep|find|sort|wc|chmod|chown|kill|pkill|sleep|curl|wget|which|env|export|source|cd|pwd|date|whoami|hostname|uname|df|du|tar|zip|unzip|man|less|more|diff|patch|xargs|tee|tr|cut|ln|test|true|false|time|nohup|timeout|mkfifo)
                words=("${words[0]}")
                ;;
        esac
        if [[ ${#words[@]} -gt 0 ]]; then
            echo "Running ${words[*]}"
        else
            echo "Running a command"
        fi
    ' -- "$command")

    if [[ "$actual" == "$expected" ]]; then
        echo "  PASS: $description"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $description"
        echo "        input:    \"$command\""
        echo "        expected: \"$expected\""
        echo "        actual:   \"$actual\""
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Git commands (program + subcommand) ==="
assert_eq "git log with flags"      "git log --oneline -3"                              "Running git log"
assert_eq "git add with files"      "git add README.md hooks/scripts/speak-step.sh"     "Running git add"
assert_eq "git status"              "git status"                                         "Running git status"
assert_eq "git diff with flag"      "git diff --staged"                                 "Running git diff"
assert_eq "git commit with msg"     "git commit -m fix"                                 "Running git commit"
assert_eq "git push"                "git push origin main"                              "Running git push"

echo ""
echo "=== Package managers (program + subcommand) ==="
assert_eq "npm install"             "npm install --save-dev foo"                        "Running npm install"
assert_eq "npm run"                 "npm run test"                                      "Running npm run"
assert_eq "pip install"             "pip install kokoro"                                "Running pip install"

echo ""
echo "=== Flag-heavy commands ==="
assert_eq "python -m pip"           "python3 -m pip install kokoro"                     "Running python3 pip"
assert_eq "gh pr create"            "gh pr create --title foo --body bar"               "Running gh pr"
assert_eq "docker compose"          "docker compose up -d"                              "Running docker compose"

echo ""
echo "=== Single-word commands (blocklist) ==="
assert_eq "ls with flags"           "ls -la /tmp"                                       "Running ls"
assert_eq "cat file"                "cat /tmp/claude-narrator-state"                    "Running cat"
assert_eq "rm with flags"           "rm -rf /tmp/test"                                  "Running rm"
assert_eq "curl with flags"         "curl -s https://example.com"                       "Running curl"
assert_eq "grep with flags"         "grep -rn pattern src/"                             "Running grep"
assert_eq "find with args"          "find . -name *.py"                                 "Running find"
assert_eq "chmod"                   "chmod +x hooks/scripts/*.sh"                       "Running chmod"
assert_eq "echo with args"         "echo hello world"                                  "Running echo"
assert_eq "sed with args"           "sed -i s/foo/bar/ file.txt"                        "Running sed"
assert_eq "pkill with flag"         "pkill -f speak-daemon"                             "Running pkill"
assert_eq "mkdir"                   "mkdir -p /tmp/test/dir"                            "Running mkdir"
assert_eq "wget"                    "wget -q https://example.com"                       "Running wget"
assert_eq "cp"                      "cp -r src/ dst/"                                   "Running cp"
assert_eq "mv"                      "mv old.txt new.txt"                                "Running mv"

echo ""
echo "=== Edge cases ==="
assert_eq "flags only"              "--flag-only"                                       "Running a command"
assert_eq "empty command"           ""                                                  "Running a command"

echo ""
echo "=============================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
else
    echo "All tests passed!"
fi
