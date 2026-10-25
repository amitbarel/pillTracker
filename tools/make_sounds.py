"""Writes the alarm tones the app offers besides the phone's own sounds.

They are synthesised here, so there is nothing to license. Android loops a
reminder's sound until it is answered, so each one ends in a short silence.

    python3 tools/make_sounds.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / 'android/app/src/main/res/raw'


def bell(freq, start, length, partials=((1, 1.0), (2.76, 0.4), (5.4, 0.2)), decay=3.0):
    """A struck tone: a few partials fading out."""
    return [(start, length, lambda t, f=freq: sum(
        a * math.sin(2 * math.pi * f * r * t) * math.exp(-decay * r ** 0.5 * t)
        for r, a in partials))]


def beep(freq, start, length):
    """A plain tone with soft edges, so it doesn't click."""
    def tone(t):
        edge = min(1.0, t / 0.01, (length - t) / 0.01)
        return 0.8 * edge * math.sin(2 * math.pi * freq * t)
    return [(start, length, tone)]


def render(name, total, notes):
    samples = [0.0] * int(total * RATE)
    for start, length, f in notes:
        s0 = int(start * RATE)
        for i in range(int(length * RATE)):
            if s0 + i < len(samples):
                samples[s0 + i] += f(i / RATE)
    peak = max(abs(x) for x in samples) or 1
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(
            struct.pack('<h', int(x / peak * 0.85 * 32767)) for x in samples))


# Three rising notes (C, E, G), gentle.
render('pill_chime', 2.4, [
    *bell(523.25, 0.0, 1.6), *bell(659.25, 0.3, 1.6), *bell(783.99, 0.6, 1.8)])
# A deeper bell, struck twice.
render('pill_bell', 3.0, [
    *bell(392.0, 0.0, 1.4, decay=1.8), *bell(392.0, 1.2, 1.6, decay=1.8)])
# The classic alarm clock: four quick beeps.
render('pill_beeps', 1.6, [
    note for i in range(4) for note in beep(1000, i * 0.2, 0.12)])
