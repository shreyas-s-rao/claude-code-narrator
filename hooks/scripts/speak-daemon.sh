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

# Bootstrap venv if needed (first run — may take several minutes)
if [[ ! -x "$VENV_PYTHON" ]]; then
    if ! python3 "$SCRIPT_DIR/ensure_venv.py" 2>"$NARRATOR_DIR/bootstrap.log"; then
        echo "Narrator venv bootstrap failed. See $NARRATOR_DIR/bootstrap.log" >&2
        exit 1
    fi
    if [[ ! -x "$VENV_PYTHON" ]]; then
        echo "Narrator venv bootstrap succeeded but python not found at $VENV_PYTHON" >&2
        exit 1
    fi
fi

PYTHON="$VENV_PYTHON"

# Launch the Python daemon (keeps pipeline loaded, reads from FIFO)
exec "$PYTHON" "$SCRIPT_DIR/speak-daemon.py" "$FIFO"
