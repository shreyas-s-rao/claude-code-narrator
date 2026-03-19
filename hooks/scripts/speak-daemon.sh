#!/usr/bin/env bash
# Speech queue daemon. Launches the Python daemon that keeps the TTS pipeline
# loaded in memory and reads utterances from a FIFO.
# Started automatically by speak.sh; killed by /narrator:hush.

set -euo pipefail

NARRATOR_DIR="$HOME/.claude-code-narrator"
mkdir -p "$NARRATOR_DIR"
FIFO="$NARRATOR_DIR/fifo"
PID_FILE="$NARRATOR_DIR/daemon.pid"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PYTHON="$HOME/.claude-narrator-venv/bin/python3"

cleanup() {
    rm -f "$PID_FILE"
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# Ensure FIFO exists and is a named pipe (not a regular file)
if [[ -e "$FIFO" && ! -p "$FIFO" ]]; then
    rm -f "$FIFO"
fi
mkfifo "$FIFO" 2>/dev/null || true

# Use venv python if available, otherwise system python3
if [[ -x "$VENV_PYTHON" ]]; then
    PYTHON="$VENV_PYTHON"
else
    PYTHON="python3"
fi

# Launch the Python daemon (keeps pipeline loaded, reads from FIFO)
exec "$PYTHON" "$SCRIPT_DIR/speak-daemon.py" "$FIFO"
