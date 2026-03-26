#!/usr/bin/env python3
"""Kokoro TTS speech synthesis. Reads text from stdin, speaks it aloud.

Auto-creates a venv at ~/.claude-narrator-venv and installs dependencies on first run.
On subsequent runs, re-execs inside the venv if not already there.
"""

import sys
import os
import subprocess

NARRATOR_DIR = os.path.expanduser('~/.claude-code-narrator')
STATE_FILE = os.path.join(NARRATOR_DIR, 'config')
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

sys.path.insert(0, SCRIPT_DIR)
from ensure_venv import ensure_venv, VENV_DIR, VENV_PYTHON


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
