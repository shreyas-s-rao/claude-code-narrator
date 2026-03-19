#!/usr/bin/env python3
"""Speech queue daemon. Keeps the Kokoro TTS pipeline loaded in memory and reads
utterances from a FIFO, speaking them sequentially with no overlap.

Usage: speak-daemon.py <fifo_path>
"""

import sys
import os
import signal

STATE_FILE = '/tmp/claude-narrator-state'
PID_FILE = '/tmp/claude-speak-daemon.pid'


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


def main():
    if len(sys.argv) < 2:
        print("Usage: speak-daemon.py <fifo_path>", file=sys.stderr)
        sys.exit(1)

    fifo_path = sys.argv[1]

    # Use cached model files — skip HF Hub network calls.
    os.environ.setdefault('HF_HUB_OFFLINE', '1')

    import kokoro
    import sounddevice as sd
    import numpy as np

    # Load pipeline once — this is the expensive step (~9s).
    pipeline = kokoro.KPipeline(lang_code='a', repo_id='hexgrad/Kokoro-82M')

    # Open FIFO read-write to prevent EOF when no writers.
    fd = os.open(fifo_path, os.O_RDWR)
    fifo = os.fdopen(fd, 'r')

    # Write PID file AFTER pipeline is loaded and FIFO is open — this signals
    # to speak.sh that we're ready to accept text.
    with open(PID_FILE, 'w') as f:
        f.write(str(os.getpid()))

    def shutdown(signum, frame):
        try:
            os.unlink(PID_FILE)
        except OSError:
            pass
        sys.exit(0)
    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    for line in fifo:
        line = line.strip()

        if line == '__QUIT__':
            break

        if not line:
            continue

        try:
            voice = os.environ.get('CLAUDE_VOICE') or read_state('voice', 'af_heart')
            speed = float(os.environ.get('CLAUDE_VOICE_SPEED') or read_state('speed', '1.1'))

            audio_chunks = []
            for gs, ps, audio in pipeline(line, voice=voice, speed=speed):
                if audio is not None:
                    audio_chunks.append(audio)

            if audio_chunks:
                full_audio = np.concatenate(audio_chunks)
                sd.play(full_audio, samplerate=24000)
                sd.wait()
        except Exception as e:
            print(f"Speech error: {e}", file=sys.stderr)


if __name__ == '__main__':
    main()
