#!/usr/bin/env python3
"""Speech queue daemon. Keeps the Kokoro TTS pipeline loaded in memory and reads
utterances from a FIFO, speaking them sequentially with no overlap.

Playback is streamed: a synthesis thread queues each chunk Kokoro produces (up
to ~510 phonemes, a few sentences), and a playback thread writes the chunks
back to back into an output stream, so speech starts after the first chunk and
plays without gaps. The stream is opened when audio arrives and closed after a
second of idle, so the audio device is not held between utterances.

Usage: speak-daemon.py <fifo_path>
"""

import sys
import os
import signal
import time
import json
import queue
import threading

NARRATOR_DIR = os.path.expanduser('~/.claude-code-narrator')
STATE_FILE = os.path.join(NARRATOR_DIR, 'config')
PID_FILE = os.path.join(NARRATOR_DIR, 'daemon.pid')

SAMPLE_RATE = 24000
# Samples per write to the output stream (0.1s): how often playback checks for a hush.
PLAYBACK_BLOCK = 2400
# Seconds without audio before the output stream is closed.
STREAM_IDLE_CLOSE = 1.0
# Queue marker for __QUIT__: passes through both workers after any earlier speech.
QUIT = object()


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

    # Bumped by every hush. Queued text and audio carry the generation they
    # were queued in, and the workers drop anything older. The signal handlers
    # only change this counter: they run on the main thread, which may be
    # inside text_q.put() holding the queue's lock.
    generation = 0

    text_q = queue.Queue()
    audio_q = queue.Queue(maxsize=64)
    quit_done = threading.Event()

    def synth_worker():
        while True:
            item = text_q.get()
            if item is QUIT:
                audio_q.put(QUIT)
                return
            gen, text, voice, speed = item
            if gen != generation:
                continue
            try:
                for gs, ps, audio in pipeline(text, voice=voice, speed=speed):
                    if gen != generation:
                        break
                    if audio is not None:
                        audio_q.put((gen, np.asarray(audio, dtype=np.float32)))
            except Exception as e:
                print(f"Speech error: {e}", file=sys.stderr)

    def close_stream(stream, abort=False):
        # abort drops buffered audio (hush); stop lets it finish playing.
        try:
            if abort:
                stream.abort()
            else:
                stream.stop()
            stream.close()
        except Exception:
            pass

    def playback_worker():
        stream = None
        while True:
            try:
                item = audio_q.get(timeout=STREAM_IDLE_CLOSE if stream else None)
            except queue.Empty:
                close_stream(stream)
                stream = None
                continue
            if item is QUIT:
                if stream:
                    close_stream(stream)
                quit_done.set()
                return
            gen, audio = item
            if gen != generation:
                if stream:
                    close_stream(stream, abort=True)
                    stream = None
                continue
            try:
                if stream is None:
                    stream = sd.OutputStream(samplerate=SAMPLE_RATE, channels=1, dtype='float32')
                    stream.start()
                for i in range(0, len(audio), PLAYBACK_BLOCK):
                    if gen != generation:
                        close_stream(stream, abort=True)
                        stream = None
                        break
                    stream.write(audio[i:i + PLAYBACK_BLOCK].reshape(-1, 1))
            except Exception as e:
                # A device change or other error: drop this stream; the next
                # chunk opens a fresh one.
                print(f"Playback error: {e}", file=sys.stderr)
                if stream:
                    close_stream(stream, abort=True)
                stream = None

    def shutdown(signum, frame):
        nonlocal generation
        # Let playback abort its stream at the next block before the
        # interpreter shuts PortAudio down.
        generation += 1
        time.sleep(3 * PLAYBACK_BLOCK / SAMPLE_RATE)
        try:
            os.unlink(PID_FILE)
        except OSError:
            pass
        sys.exit(0)

    def hush(signum, frame):
        nonlocal hush_time, generation
        hush_time = time.monotonic()
        generation += 1

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGUSR1, hush)

    threading.Thread(target=synth_worker, daemon=True).start()
    threading.Thread(target=playback_worker, daemon=True).start()

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
                # Finish what is already queued, then exit.
                text_q.put(QUIT)
                quit_done.wait()
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
                # Parse JSON lines for per-utterance voice/speed.
                # Plain text lines (backward compat) fall back to global state.
                utterance_text = line
                utterance_voice = None
                utterance_speed = None
                if line.startswith('{'):
                    try:
                        msg = json.loads(line)
                        utterance_text = msg.get('text', line)
                        utterance_voice = msg.get('voice')
                        utterance_speed = msg.get('speed')
                    except json.JSONDecodeError:
                        pass  # treat as plain text

                if not utterance_text.strip():
                    continue

                voice = utterance_voice or os.environ.get('CLAUDE_VOICE') or read_state('voice', 'af_heart')
                speed = float(utterance_speed if utterance_speed is not None else (os.environ.get('CLAUDE_VOICE_SPEED') or read_state('speed', '1.1')))

                text_q.put((generation, utterance_text, voice, speed))
            except Exception as e:
                print(f"Speech error: {e}", file=sys.stderr)

    # Clean up PID file on normal exit.
    try:
        os.unlink(PID_FILE)
    except OSError:
        pass


if __name__ == '__main__':
    main()
