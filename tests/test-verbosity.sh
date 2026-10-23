#!/usr/bin/env bash
# Tests for the verbosity and length settings in the hook scripts.
# Run: bash tests/test-verbosity.sh
#
# The hook scripts are copied into a temp dir with speak.sh swapped for a stub
# that records what would have been spoken, HOME points at a temp config, and
# each case runs a hook with a sample payload. A hook that exits non-zero
# fails the case, so "nothing spoken" always means the setting silenced it.

set -euo pipefail

PASS=0
FAIL=0

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK=$(mktemp -d)
HUSH_TARGET=""
cleanup() {
    [[ -n "$HUSH_TARGET" ]] && kill "$HUSH_TARGET" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

SCRIPTS="$WORK/scripts"
cp -R "$REPO_DIR/hooks/scripts" "$SCRIPTS"
SPOKEN="$WORK/spoken"
cat > "$SCRIPTS/speak.sh" <<EOF
#!/usr/bin/env bash
cat >> "$SPOKEN"
EOF

export HOME="$WORK/home"
mkdir -p "$HOME/.claude-code-narrator"

# A transcript whose current turn has one intermediate text block.
TRANSCRIPT="$WORK/transcript.jsonl"
cat > "$TRANSCRIPT" <<'EOF'
{"type":"user","message":{"content":"hi"}}
{"type":"assistant","message":{"id":"msg_1","content":[{"type":"text","text":"Checking the config first."}]}}
EOF

# A plan file, as Claude Code writes them in plan mode.
PLAN="$WORK/.claude/plans/plan.md"
mkdir -p "$(dirname "$PLAN")"
printf 'Step one of the plan.\n' > "$PLAN"

LONG_TEXT=$(for i in $(seq 1 100); do printf 'Sentence number %s. ' "$i"; done)

set_config() {
    printf '%s\n' "$@" > "$HOME/.claude-code-narrator/config"
    rm -f "$HOME/.claude-code-narrator/last-spoken"
}

# Runs a hook and prints what it spoke; prints HOOK_FAILED if it exited non-zero.
run_hook() {
    local script="$1" payload="$2"
    : > "$SPOKEN"
    if ! printf '%s\n' "$payload" | bash "$SCRIPTS/$script" >/dev/null 2>&1; then
        echo "HOOK_FAILED"
    fi
    cat "$SPOKEN"
}

step_payload() {
    printf '{"cwd":"%s","tool_name":"Read","tool_input":{"file_path":"/x/settings.json"},"tool_use_id":"t1","transcript_path":"%s"}' "$WORK" "$TRANSCRIPT"
}
plan_payload() {
    printf '{"cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s"},"permission_mode":"plan"}' "$WORK" "$PLAN"
}
ask_payload() {
    printf '{"cwd":"%s","tool_name":"AskUserQuestion","tool_input":{}}' "$WORK"
}
# response_payload <text> [permission_mode]
response_payload() {
    printf '{"cwd":"%s","last_assistant_message":"%s"%s}' "$WORK" "$1" "${2:+,\"permission_mode\":\"$2\"}"
}
notification_payload() {
    printf '{"cwd":"%s","title":"Claude","message":"Needs your permission"}' "$WORK"
}

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() {
    echo "  FAIL: $1"
    shift
    for line in "$@"; do echo "        $line"; done
    FAIL=$((FAIL + 1))
}

assert_contains() {
    local description="$1" actual="$2" needle="$3"
    if [[ "$actual" != *HOOK_FAILED* && "$actual" == *"$needle"* ]]; then
        pass "$description"
    else
        fail "$description" "expected to contain: \"$needle\"" "actual:              \"$actual\""
    fi
}

assert_not_contains() {
    local description="$1" actual="$2" needle="$3"
    if [[ "$actual" != *HOOK_FAILED* && "$actual" != *"$needle"* ]]; then
        pass "$description"
    else
        fail "$description" "expected not to contain: \"$needle\"" "actual:                  \"$actual\""
    fi
}

assert_empty() {
    local description="$1" actual="$2"
    if [[ -z "$actual" ]]; then
        pass "$description"
    else
        fail "$description" "expected nothing spoken, got: \"$actual\""
    fi
}

assert_shorter_than() {
    local description="$1" actual="$2" max="$3"
    if [[ "$actual" != *HOOK_FAILED* && -n "$actual" && ${#actual} -lt $max ]]; then
        pass "$description"
    else
        fail "$description" "expected 1..$((max - 1)) chars, got ${#actual}"
    fi
}

echo "=== verbose (default, no verbosity key) ==="
set_config "enabled=true"
out=$(run_hook speak-step.sh "$(step_payload)")
assert_contains "speaks the intermediate text block" "$out" "Checking the config first."
assert_contains "speaks the tool description"        "$out" "Reading file settings.json"
assert_contains "speaks the final response" "$(run_hook speak-response.sh "$(response_payload "All done.")")" "All done."
assert_contains "speaks notifications"      "$(run_hook speak-notification.sh "$(notification_payload)")" "Needs your permission"
assert_contains "reads plan files"          "$(run_hook speak-step.sh "$(plan_payload)")" "Step one of the plan."

echo "=== normal ==="
set_config "enabled=true" "verbosity=normal"
out=$(run_hook speak-step.sh "$(step_payload)")
assert_contains     "speaks the tool description"       "$out" "Reading file settings.json"
assert_not_contains "skips the intermediate text block" "$out" "Checking the config first."
assert_contains "speaks the final response" "$(run_hook speak-response.sh "$(response_payload "All done.")")" "All done."
assert_empty    "skips notifications"       "$(run_hook speak-notification.sh "$(notification_payload)")"
assert_contains "reads plan files"          "$(run_hook speak-step.sh "$(plan_payload)")" "Step one of the plan."

echo "=== minimal ==="
set_config "enabled=true" "verbosity=minimal"
out=$(run_hook speak-step.sh "$(step_payload)")
assert_contains     "speaks the tool description"       "$out" "Reading file settings.json"
assert_not_contains "skips the intermediate text block" "$out" "Checking the config first."
assert_empty "skips the final response" "$(run_hook speak-response.sh "$(response_payload "All done.")")"
assert_empty "skips notifications"      "$(run_hook speak-notification.sh "$(notification_payload)")"
out=$(run_hook speak-step.sh "$(plan_payload)")
assert_contains     "describes a plan file write" "$out" "Writing file plan.md"
assert_not_contains "does not read the plan"      "$out" "Step one of the plan."

echo "=== final ==="
set_config "enabled=true" "verbosity=final"
assert_empty    "skips tool steps and text blocks" "$(run_hook speak-step.sh "$(step_payload)")"
assert_contains "speaks the final response" "$(run_hook speak-response.sh "$(response_payload "All done.")")" "All done."
assert_empty    "skips notifications"       "$(run_hook speak-notification.sh "$(notification_payload)")"
assert_contains "reads plan files"          "$(run_hook speak-step.sh "$(plan_payload)")" "Step one of the plan."
# AskUserQuestion still hushes: point daemon.pid at a stand-in process and
# check it received SIGUSR1: it exits 42 on SIGUSR1 and 0 if none arrives.
bash -c 'trap "exit 42" USR1; sleep 5 & wait' &
HUSH_TARGET=$!
printf '%s' "$HUSH_TARGET" > "$HOME/.claude-code-narrator/daemon.pid"
out=$(run_hook speak-step.sh "$(ask_payload)")
status=0
wait "$HUSH_TARGET" 2>/dev/null || status=$?
if [[ -z "$out" && $status -eq 42 ]]; then
    pass "AskUserQuestion still hushes"
else
    fail "AskUserQuestion still hushes" "spoken: \"$out\"; stand-in exit status $status"
fi
HUSH_TARGET=""
rm -f "$HOME/.claude-code-narrator/daemon.pid"

echo "=== values are normalized; unknown values fall back to the defaults ==="
set_config "enabled=true" "verbosity= Final"
assert_empty "' Final' is final" "$(run_hook speak-step.sh "$(step_payload)")"
set_config "enabled=true" $'verbosity=final\r'
assert_empty "a CRLF line ending is ignored" "$(run_hook speak-step.sh "$(step_payload)")"
set_config "enabled=true" "verbosity=loud"
assert_contains "unknown level speaks text blocks (verbose)" "$(run_hook speak-step.sh "$(step_payload)")" "Checking the config first."
assert_contains "unknown level speaks the final response" "$(run_hook speak-response.sh "$(response_payload "All done.")")" "All done."
assert_contains "unknown level speaks notifications" "$(run_hook speak-notification.sh "$(notification_payload)")" "Needs your permission"
set_config "enabled=true" "length=everything"
assert_shorter_than "unknown length is summary" "$(run_hook speak-response.sh "$(response_payload "$LONG_TEXT")")" 1100

echo "=== length ==="
set_config "enabled=true"
assert_shorter_than "summary (default) cuts long responses" "$(run_hook speak-response.sh "$(response_payload "$LONG_TEXT")")" 1100
set_config "enabled=true" "length=full"
assert_contains "full speaks the whole response" "$(run_hook speak-response.sh "$(response_payload "$LONG_TEXT")")" "Sentence number 100."
set_config "enabled=true" "length=summary"
assert_contains "plan mode speaks the whole response at summary" "$(run_hook speak-response.sh "$(response_payload "$LONG_TEXT" plan)")" "Sentence number 100."

echo "=== local config overrides global ==="
set_config "enabled=true" "verbosity=verbose"
mkdir -p "$WORK/.claude-code-narrator"
printf 'verbosity=final\n' > "$WORK/.claude-code-narrator/config"
assert_empty "local final silences tool steps" "$(run_hook speak-step.sh "$(step_payload)")"
rm -rf "$WORK/.claude-code-narrator"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
