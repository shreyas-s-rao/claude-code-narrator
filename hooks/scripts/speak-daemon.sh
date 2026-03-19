#!/usr/bin/env bash
# Speech queue daemon. Launches the Python daemon that keeps the TTS pipeline
# loaded in memory and reads utterances from a FIFO.
# Started automatically by speak.sh; killed by /narrator:hush.

set -euo pipefail

FIFO="/tmp/claude-speak-fifo"
PID_FILE="/tmp/claude-speak-daemon.pid"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PYTHON="$HOME/.claude-narrator-venv/bin/python3"

cleanup() {
    rm -f "$PID_FILE"
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# Create FIFO if it doesn't exist
mkfifo "$FIFO" 2>/dev/null || true

# Use venv python if available, otherwise system python3
if [[ -x "$VENV_PYTHON" ]]; then
    PYTHON="$VENV_PYTHON"
else
    PYTHON="python3"
fi

# Launch the Python daemon (keeps pipeline loaded, reads from FIFO)
exec "$PYTHON" "$SCRIPT_DIR/speak-daemon.py" "$FIFO"
