#!/usr/bin/env python3
"""Kokoro TTS speech synthesis. Reads text from stdin, speaks it aloud.

Auto-creates a venv at ~/.claude-narrator-venv and installs dependencies on first run.
On subsequent runs, re-execs inside the venv if not already there.
"""

import sys
import os
import subprocess

STATE_FILE = '/tmp/claude-narrator-state'
VENV_DIR = os.path.join(os.path.expanduser('~'), '.claude-narrator-venv')
VENV_PYTHON = os.path.join(VENV_DIR, 'bin', 'python3')


def read_state(key, default):
    """Read a value from the state file, with a default."""
    try:
        with open(STATE_FILE, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith(key + '='):
                    return line.split('=', 1)[1]
    except FileNotFoundError:
        pass
    return default


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


def speak(text):
    """Synthesize and play speech."""
    import kokoro
    import sounddevice as sd
    import numpy as np

    voice = os.environ.get('CLAUDE_VOICE') or read_state('voice', 'af_heart')
    speed = float(os.environ.get('CLAUDE_VOICE_SPEED') or read_state('speed', '1.1'))

    pipeline = kokoro.KPipeline(lang_code='a', repo_id='hexgrad/Kokoro-82M')

    audio_chunks = []
    for gs, ps, audio in pipeline(text, voice=voice, speed=speed):
        if audio is not None:
            audio_chunks.append(audio)

    if not audio_chunks:
        return

    full_audio = np.concatenate(audio_chunks)
    sd.play(full_audio, samplerate=24000)
    sd.wait()


if __name__ == '__main__':
    text = sys.stdin.read().strip()
    if not text:
        sys.exit(0)

    in_venv = sys.prefix != sys.base_prefix

    if in_venv:
        # Already inside the venv — just speak
        speak(text)
    else:
        # Check if kokoro is available in current env
        try:
            import kokoro
            import sounddevice
            import numpy
            speak(text)
        except ImportError:
            # Need the venv — set it up, then re-invoke inside it
            ensure_venv()
            proc = subprocess.run(
                [VENV_PYTHON, os.path.abspath(__file__)],
                input=text, text=True,
            )
            sys.exit(proc.returncode)
