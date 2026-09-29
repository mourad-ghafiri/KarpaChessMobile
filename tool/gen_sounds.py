#!/usr/bin/env python3
"""Generates the app's sound packs into assets/audio/<pack>/.

Board impacts use MODAL SYNTHESIS — a sum of exponentially decaying
resonant modes plus a noise transient, the standard technique for
realistic impact sounds. Three packs:

  wood     resonant low modes, felt-damped tap  (wooden board feel)
  plastic  brighter, faster modes, clicky       (club plastic set)
  soft     low-passed muffled thump             (quiet felt room)

UI feedback effects (good/bad/win/lose/promote) are shared chimes,
rendered quietly per pack. Run from the repo root:
    python3 tool/gen_sounds.py
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
ROOT = Path(__file__).resolve().parent.parent / "assets" / "audio"
rng = random.Random(20260815)


def modal_impact(modes, dur, strike=0.5, tap=0.25, tap_freq=3000.0):
    """modes: list of (freq_hz, amplitude, decay_seconds)."""
    n = int(SR * dur)
    out = [0.0] * n
    # Random micro-detune per strike keeps repeats organic.
    detune = 1.0 + rng.uniform(-0.015, 0.015)
    for freq, amp, decay in modes:
        phase = rng.uniform(0, 2 * math.pi)
        for i in range(n):
            t = i / SR
            out[i] += amp * math.exp(-t / decay) * \
                math.sin(2 * math.pi * freq * detune * t + phase)
    # Contact transient: a couple ms of band-shaped noise.
    burst = int(SR * 0.0025)
    prev = 0.0
    for i in range(min(burst * 3, n)):
        noise = rng.uniform(-1, 1)
        # crude high-pass by differencing, tilted by tap_freq
        hp = noise - prev * (1.0 - min(tap_freq / SR * 6, 0.95))
        prev = noise
        env = math.exp(-i / (SR * 0.0012))
        out[i] += tap * hp * env
    # Strike softness: quick attack ramp.
    attack = max(1, int(SR * 0.0008 / max(strike, 0.1)))
    for i in range(min(attack, n)):
        out[i] *= i / attack
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak for v in out]


def lowpass(samples, alpha):
    out = []
    y = 0.0
    for x in samples:
        y += alpha * (x - y)
        out.append(y)
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak for v in out]


def tone(freq, dur=0.10, vol=0.10):
    n = int(SR * dur)
    attack = int(SR * 0.008)
    out = []
    for i in range(n):
        env = (i / attack if i < attack else
               math.exp(-(i - attack) / (SR * 0.045)))
        out.append(vol * env * math.sin(2 * math.pi * freq * i / SR))
    return out


def mix(events, tail=0.05):
    total = int(SR * (max(off + len(s) / SR for off, s in events) + tail))
    buf = [0.0] * total
    for off, samples in events:
        start = int(SR * off)
        for i, v in enumerate(samples):
            buf[start + i] += v
    peak = max(abs(v) for v in buf)
    if peak > 0.88:
        buf = [v * 0.88 / peak for v in buf]
    return buf


def write(pack, name, buf):
    directory = ROOT / pack
    directory.mkdir(parents=True, exist_ok=True)
    with wave.open(str(directory / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in buf))


def scaled(samples, vol):
    return [v * vol for v in samples]


# ---- pack definitions -----------------------------------------------------

def wood_hit(vol=0.85, low=1.0):
    return scaled(modal_impact(
        [(128 * low, 1.0, 0.045), (241 * low, 0.65, 0.030),
         (413 * low, 0.35, 0.018), (988 * low, 0.12, 0.008)],
        dur=0.16, tap=0.30, tap_freq=2500), vol)


def plastic_hit(vol=0.8, low=1.0):
    return scaled(modal_impact(
        [(415 * low, 1.0, 0.014), (905 * low, 0.8, 0.010),
         (1780 * low, 0.55, 0.006), (3200 * low, 0.25, 0.003)],
        dur=0.07, tap=0.5, tap_freq=6000), vol)


def soft_hit(vol=0.7, low=1.0):
    return scaled(lowpass(modal_impact(
        [(110 * low, 1.0, 0.060), (205 * low, 0.5, 0.040)],
        dur=0.18, tap=0.10, tap_freq=900), 0.12), vol)


PACK_HITS = {
    "wood": wood_hit,
    "plastic": plastic_hit,
    "soft": soft_hit,
}

for pack, hit in PACK_HITS.items():
    effects = {
        "move":    [(0.000, hit())],
        "capture": [(0.000, hit(vol=0.9)),
                    (0.050, hit(vol=0.95, low=0.82))],
        "castle":  [(0.000, hit(vol=0.7)),
                    (0.090, hit(vol=0.85, low=0.95))],
        "check":   [(0.000, hit(vol=0.95, low=0.9)),
                    (0.030, tone(660, dur=0.12, vol=0.05))],
        # shared quiet chimes
        "promote": [(i * 0.055, tone(f, dur=0.09, vol=0.08))
                    for i, f in enumerate([523, 659, 784, 1047])],
        "win":     [(i * 0.085, tone(f, dur=0.14, vol=0.09))
                    for i, f in enumerate([523, 659, 784, 988, 1319])],
        "lose":    [(i * 0.10, tone(f, dur=0.15, vol=0.06))
                    for i, f in enumerate([392, 330, 262, 196])],
        "good":    [(0.000, tone(880, dur=0.09, vol=0.08)),
                    (0.070, tone(1319, dur=0.11, vol=0.08))],
        "bad":     [(0.000, tone(220, dur=0.12, vol=0.07)),
                    (0.010, hit(vol=0.3, low=0.7))],
    }
    for name, events in effects.items():
        buf = mix(events)
        write(pack, name, buf)
    print(f"{pack}: 9 effects rendered")
