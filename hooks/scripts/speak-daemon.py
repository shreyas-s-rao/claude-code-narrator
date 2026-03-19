#!/usr/bin/env python3
"""Speech queue daemon. Keeps the Kokoro TTS pipeline loaded in memory and reads
utterances from a FIFO, speaking them sequentially with no overlap.

Usage: speak-daemon.py <fifo_path>
"""

import sys
import os
import signal
import time

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

    import kokoro
    import sounddevice as sd
    import numpy as np

    # Load pipeline once — this is the expensive step (~9s).
    pipeline = kokoro.KPipeline(lang_code='a', repo_id='hexgrad/Kokoro-82M')

    # Open FIFO read-write to prevent EOF when no writers.
    fd = os.open(fifo_path, os.O_RDWR)

    # Write PID file AFTER pipeline is loaded and FIFO is open — this signals
    # to speak.sh that we're ready to accept text.
    with open(PID_FILE, 'w') as f:
        f.write(str(os.getpid()))

    # Timestamp of last SIGUSR1 (hush). Lines received before this are skipped.
    hush_time = 0.0

    def shutdown(signum, frame):
        sd.stop()
        try:
            os.unlink(PID_FILE)
        except OSError:
            pass
        sys.exit(0)

    def hush(signum, frame):
        nonlocal hush_time
        hush_time = time.monotonic()
        sd.stop()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGUSR1, hush)

    buf = b''
    while True:
        try:
            data = os.read(fd, 4096)
        except OSError:
            break
        if not data:
            continue

        buf += data
        while b'\n' in buf:
            line_bytes, buf = buf.split(b'\n', 1)
            line = line_bytes.decode('utf-8', errors='replace').strip()

            if line == '__QUIT__':
                try:
                    os.unlink(PID_FILE)
                except OSError:
                    pass
                return

            if not line:
                continue

            # Record when this line was dequeued. If a hush arrived recently,
            # skip it — it was queued before the user provided input.
            now = time.monotonic()
            if now - hush_time < 5.0:
                # Line was buffered before the hush — discard.
                continue

            try:
                voice = os.environ.get('CLAUDE_VOICE') or read_state('voice', 'af_heart')
                speed = float(os.environ.get('CLAUDE_VOICE_SPEED') or read_state('speed', '1.1'))

                audio_chunks = []
                for gs, ps, audio in pipeline(line, voice=voice, speed=speed):
                    if audio is not None:
                        audio_chunks.append(audio)

                # Check again after synthesis — hush may have arrived mid-TTS.
                if time.monotonic() - hush_time < 5.0:
                    continue

                if audio_chunks:
                    full_audio = np.concatenate(audio_chunks)
                    sd.play(full_audio, samplerate=24000)
                    sd.wait()
            except Exception as e:
                print(f"Speech error: {e}", file=sys.stderr)

    # Clean up PID file on normal exit.
    try:
        os.unlink(PID_FILE)
    except OSError:
        pass


if __name__ == '__main__':
    main()
