#!/usr/bin/env bash
# Run all narrator tests.
# Usage: bash tests/run-all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_FAIL=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Running $(basename "$test_file")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if bash "$test_file"; then
        echo ""
    else
        ((TOTAL_FAIL++))
        echo ""
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $TOTAL_FAIL -gt 0 ]]; then
    echo "$TOTAL_FAIL test suite(s) had failures."
    exit 1
else
    echo "All test suites passed!"
fi
