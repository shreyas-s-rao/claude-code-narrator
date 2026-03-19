#!/usr/bin/env bash
# Tests for the filename dot replacement in speak.sh.
# Run: bash tests/test-dot-replacement.sh

set -euo pipefail

PASS=0
FAIL=0

assert_eq() {
    local description="$1"
    local input="$2"
    local expected="$3"

    local actual
    actual=$(echo "$input" | sed -E 's/([a-zA-Z0-9_-]{2,})\.([a-zA-Z]{1,10})/\1 dot \2/g; s/(dot [a-zA-Z0-9_-]+)\.([a-zA-Z]{1,10})/\1 dot \2/g')

    if [[ "$actual" == "$expected" ]]; then
        echo "  PASS: $description"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $description"
        echo "        input:    \"$input\""
        echo "        expected: \"$expected\""
        echo "        actual:   \"$actual\""
        FAIL=$((FAIL + 1))
    fi
}

echo "=== File extensions ==="
assert_eq "json file"          "Reading file settings.json"       "Reading file settings dot json"
assert_eq "python file"        "Writing file kokoro-speak.py"     "Writing file kokoro-speak dot py"
assert_eq "markdown file"      "Editing file README.md"           "Editing file README dot md"
assert_eq "shell script"       "Reading file speak-daemon.sh"     "Reading file speak-daemon dot sh"
assert_eq "yaml file"          "Reading file docker-compose.yml"  "Reading file docker-compose dot yml"
assert_eq "lock file"          "Reading file package-lock.json"   "Reading file package-lock dot json"
assert_eq "underscore file"    "Reading file my_module.py"        "Reading file my_module dot py"
assert_eq "typescript file"    "Writing file index.ts"            "Writing file index dot ts"
assert_eq "css file"           "Editing file styles.css"          "Editing file styles dot css"
assert_eq "toml file"          "Reading file pyproject.toml"      "Reading file pyproject dot toml"

echo ""
echo "=== Chained extensions ==="
assert_eq "test.ts"            "Editing file foo.test.ts"         "Editing file foo dot test dot ts"
assert_eq "spec.jsx"           "Reading file component.spec.jsx"  "Reading file component dot spec dot jsx"
assert_eq "module.css"         "Writing file styles.module.css"   "Writing file styles dot module dot css"
assert_eq "base.json"          "Reading file tsconfig.base.json"  "Reading file tsconfig dot base dot json"
assert_eq "d.ts"               "Reading file types.d.ts"          "Reading file types dot d dot ts"

echo ""
echo "=== Sentences (should NOT change) ==="
assert_eq "two sentences"      "Narrator is now enabled. I will speak responses aloud." \
                               "Narrator is now enabled. I will speak responses aloud."
assert_eq "three sentences"    "Done. The file was updated. Moving on." \
                               "Done. The file was updated. Moving on."
assert_eq "question mark"      "What happened? Let me check." \
                               "What happened? Let me check."
assert_eq "exclamation"        "Success! All tests passed." \
                               "Success! All tests passed."
assert_eq "no dots"            "Running git log" \
                               "Running git log"

echo ""
echo "=== Abbreviations (should NOT change) ==="
assert_eq "e.g."               "e.g. this is an example"          "e.g. this is an example"
assert_eq "i.e."               "i.e. in other words"              "i.e. in other words"
assert_eq "Dr."                "Dr. Smith is here"                "Dr. Smith is here"
assert_eq "U.S.A."             "U.S.A. is a country"              "U.S.A. is a country"
assert_eq "etc."               "etc. and so on"                   "etc. and so on"

echo ""
echo "=== Version numbers (should NOT change) ==="
assert_eq "semver"             "Installed numpy 1.26.4"           "Installed numpy 1.26.4"
assert_eq "python version"     "Using Python 3.13.2"              "Using Python 3.13.2"
assert_eq "prefixed version"   "Version v2.0.1 released"          "Version v2.0.1 released"

echo ""
echo "=== Ellipsis (should NOT change) ==="
assert_eq "trailing ellipsis"  "Loading..."                       "Loading..."
assert_eq "mid ellipsis"       "Thinking... done"                 "Thinking... done"

echo ""
echo "=== Dotfiles (should NOT change) ==="
assert_eq ".gitignore"         "Reading file .gitignore"          "Reading file .gitignore"
assert_eq ".env"               "Reading file .env"                "Reading file .env"
assert_eq ".hidden"            ".hidden"                          ".hidden"

echo ""
echo "=== Edge cases ==="
assert_eq "no extension"       "Reading file Makefile"            "Reading file Makefile"
assert_eq "trailing dot"       "file."                            "file."
assert_eq "single char ext"    "foo.x"                            "foo dot x"
assert_eq "empty string"       ""                                 ""

echo ""
echo "=============================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
else
    echo "All tests passed!"
fi
