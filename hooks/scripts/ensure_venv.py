#!/usr/bin/env python3
"""Bootstrap the narrator venv (~/.claude-narrator-venv) with Kokoro TTS dependencies.

Can be run as a standalone script or called from other scripts via subprocess.
"""

import sys
import os
import subprocess

VENV_DIR = os.path.join(os.path.expanduser('~'), '.claude-narrator-venv')
VENV_PYTHON = os.path.join(VENV_DIR, 'bin', 'python3')


def ensure_venv():
    """Create venv and install dependencies if needed."""
    if not os.path.isfile(VENV_PYTHON):
        print("Creating narrator venv...", file=sys.stderr)
        subprocess.check_call([sys.executable, "-m", "venv", VENV_DIR], stderr=sys.stderr)

    result = subprocess.run(
        [VENV_PYTHON, "-c", "import kokoro; import sounddevice; import numpy"],
        capture_output=True,
    )
    if result.returncode != 0:
        print("Installing Kokoro TTS dependencies (first run)...", file=sys.stderr)
        # Pre-install spacy stack with pinned versions that have cp313 wheels,
        # avoiding the blis source-compile failure on Python 3.13.
        subprocess.check_call(
            [VENV_PYTHON, "-m", "pip", "install",
             "blis>=1.3.0,<1.4.0", "thinc>=8.3.10,<8.4.0", "spacy>=3.8.7,<4"],
            stdout=sys.stderr, stderr=sys.stderr,
        )
        # Install misaki from git without [en] extras (PyPI blocks Python 3.13).
        # Then install the en extras manually, skipping spacy-curated-transformers
        # which pulls in thinc 9.x -> blis 0.7.x (broken on Python 3.13).
        subprocess.check_call(
            [VENV_PYTHON, "-m", "pip", "install",
             "misaki @ git+https://github.com/hexgrad/misaki.git"],
            stdout=sys.stderr, stderr=sys.stderr,
        )
        subprocess.check_call(
            [VENV_PYTHON, "-m", "pip", "install",
             "num2words", "phonemizer-fork", "espeakng-loader",
             "torch", "transformers", "attrs"],
            stdout=sys.stderr, stderr=sys.stderr,
        )
        # Install kokoro from git without deps (misaki already installed above).
        subprocess.check_call(
            [VENV_PYTHON, "-m", "pip", "install", "--no-deps",
             "kokoro @ git+https://github.com/hexgrad/kokoro.git"],
            stdout=sys.stderr, stderr=sys.stderr,
        )
        # Install remaining kokoro deps.
        subprocess.check_call(
            [VENV_PYTHON, "-m", "pip", "install",
             "sounddevice", "numpy", "scipy", "huggingface-hub", "loguru"],
            stdout=sys.stderr, stderr=sys.stderr,
        )


if __name__ == '__main__':
    ensure_venv()
