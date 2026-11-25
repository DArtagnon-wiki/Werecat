"""Synthesizes Werecat's music and sound effects. No samples, all math.

Run from the repo root:  python3 tools/gen_audio.py
Needs numpy, scipy, ffmpeg. Output: assets/audio/*.ogg

Music: two loops with identical tempo (84 BPM), key (D minor) and chords
(Dm - Bb - Gm - A), 16 bars each, so the game can crossfade them by the
werecat's morph value:
  music_cute.ogg  - music box lullaby, celesta arpeggios, pizzicato bass, soft pad
  music_scary.ogg - pipe-organ drone, heartbeat, sub bass, theremin, choir, tremolo
"""
import os
import subprocess

import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
TMP = os.path.join(ROOT, "tools", "build")
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)
rng = np.random.default_rng(7)

BPM = 84
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = 16
LOOP = BAR * BARS

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def hz(n):
    name, octv = n[:-1], int(n[-1])
    midi = 12 * (octv + 1) + NOTE[name]
    return 440.0 * 2 ** ((midi - 69) / 12)


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def lp(x, fc, order=2):
    return sosfilt(butter(order, fc, "low", fs=SR, output="sos"), x)


def hp(x, fc, order=2):
    return sosfilt(butter(order, fc, "high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def adsr(n, a, d, s, r, sr=SR):
    a, d, r = int(a * sr), int(d * sr), int(r * sr)
    env = np.ones(n) * s
    env[:a] = np.linspace(0, 1, a, endpoint=False) if a else env[:a]
    env[a:a + d] = np.linspace(1, s, max(1, min(d, n - a)))[:max(0, min(d, n - a))]
    if r:
        env[-r:] *= np.linspace(1, 0, r)
    return env


def place(buf, sig, at, gain=1.0, pan=0.0):
    """Mix mono `sig` into stereo `buf` at time `at` (wraps for seamless loops)."""
    i = int(at * SR)
    l = gain * np.sqrt(0.5 * (1 - pan))
    r = gain * np.sqrt(0.5 * (1 + pan))
    n = len(sig)
    end = i + n
    if end <= len(buf):
        buf[i:end, 0] += sig * l
        buf[i:end, 1] += sig * r
    else:
        k = len(buf) - i
        buf[i:, 0] += sig[:k] * l
        buf[i:, 1] += sig[:k] * r
        buf[:n - k, 0] += sig[k:] * l
        buf[:n - k, 1] += sig[k:] * r


def reverb(x, seconds, wet, seed=0, damp=4000):
    """Stereo convolution reverb with a decorrelated exponential-noise IR."""
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    tt = np.arange(n) / SR
    out = np.zeros_like(x)
    for ch in range(2):
        ir = r.standard_normal(n) * np.exp(-6.9 * tt / seconds)
        ir = lp(ir, damp)
        ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        # circular convolution keeps the loop seamless
        L = len(x)
        y = np.fft.irfft(np.fft.rfft(x[:, ch], L + n) * np.fft.rfft(ir, L + n), L + n)
        y[:n] += y[L:L + n]
        out[:, ch] = y[:L]
    return x * (1 - wet) + out * wet * 2.2


def normalize(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x * (peak / m)


def loudness_match(x, target_db=-17.0, peak=0.9):
    """Match loudness as heard on a phone speaker (ignore < 180 Hz), then
    soft-limit peaks. Keeps the cute/scary crossfade level."""
    mono = x.mean(1) if x.ndim == 2 else x
    heard = hp(mono, 180, 2)
    rms = np.sqrt(np.mean(heard ** 2)) + 1e-9
    y = x * (10 ** (target_db / 20) / rms)
    return np.tanh(y / peak) * peak


def softclip(x, drive=1.2):
    return np.tanh(x * drive) / np.tanh(drive)


def save(name, x, quality=5):
    wav = os.path.join(TMP, name + ".wav")
    from scipy.io import wavfile
    wavfile.write(wav, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
                    "-q:a", str(quality), os.path.join(OUT, name + ".ogg")], check=True)


# ------------------------------------------------------------------ instruments

def music_box(f, dur=1.6, bright=1.0):
    tt = t_(dur)
    partials = [(1.0, 1.0, 1.8), (2.0, 0.28 * bright, 3.0), (3.0, 0.12 * bright, 4.5),
                (5.4, 0.08 * bright, 7.0), (8.9, 0.03 * bright, 10.0)]
    s = sum(a * np.sin(2 * np.pi * f * k * tt) * np.exp(-tt * dk) for k, a, dk in partials)
    click = rng.standard_normal(len(tt)) * np.exp(-tt * 400) * 0.08
    out = (s + hp(click, 3000)) * 0.5
    out[: int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
    return out


def broken_music_box(f, dur=2.2):
    """Detuned, warbling music box for the scary layer: the lullaby gone wrong."""
    tt = t_(dur)
    wow = 1 + 0.008 * np.sin(2 * np.pi * 0.7 * tt) + 0.004 * np.sin(2 * np.pi * 6.3 * tt)
    ph = 2 * np.pi * np.cumsum(f * 0.983 * wow) / SR
    s = (np.sin(ph) + 0.4 * np.sin(2.01 * ph) * np.exp(-tt * 2) + 0.25 * np.sin(3.97 * ph) * np.exp(-tt * 3)
         + 0.2 * np.sin(5.43 * ph) * np.exp(-tt * 5))
    out = s * np.exp(-tt * 1.3) * 0.45
    out[: int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
    return out


def celesta(f, dur=0.9):
    tt = t_(dur)
    s = np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * f * 4 * tt) * np.exp(-tt * 8)
    return s * np.exp(-tt * 4.5) * 0.35


def pluck(f, dur=0.7):
    """Karplus-Strong pizzicato."""
    n = int(dur * SR)
    p = int(SR / f)
    buf = rng.uniform(-1, 1, p)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = 0.5 * (buf[i % p] + buf[(i + 1) % p]) * 0.994
    return lp(out, 1800) * np.exp(-np.arange(n) / SR * 3.5) * 0.7


def pad(freqs, dur, cutoff=1400, detune=0.004, attack=0.6, release=0.8):
    tt = t_(dur)
    s = np.zeros(len(tt))
    for f in freqs:
        for d in (-detune, 0, detune):
            ph = rng.uniform(0, 1)
            s += 2 * ((f * (1 + d) * tt + ph) % 1) - 1
    s = lp(s / (len(freqs) * 3), cutoff, 2)
    return s * adsr(len(tt), attack, 0.3, 0.85, release)


def organ(freqs, dur, attack=0.25, release=0.6, trem=5.2):
    tt = t_(dur)
    s = np.zeros(len(tt))
    for f in freqs:
        for k, a in [(1, 1.0), (2, 0.6), (3, 0.35), (4, 0.25), (6, 0.12), (8, 0.08)]:
            s += a * np.sin(2 * np.pi * f * k * tt + rng.uniform(0, 6.28))
    s *= 1 + 0.12 * np.sin(2 * np.pi * trem * tt)
    return s / len(freqs) * 0.22 * adsr(len(tt), attack, 0.2, 0.9, release)


def theremin(notes, step):
    """Gliding sine with vibrato. notes: list of note names or None per step."""
    dur = step * len(notes)
    tt = t_(dur)
    f = np.zeros(len(tt))
    amp = np.zeros(len(tt))
    cur = hz(notes[0] or "D5")
    for i, n in enumerate(notes):
        a, b = int(i * step * SR), int((i + 1) * step * SR)
        if n:
            target = hz(n)
            glide = np.linspace(cur, target, min(b - a, int(0.09 * SR)))
            seg = np.full(b - a, target)
            seg[:len(glide)] = glide
            f[a:b] = seg
            cur = target
            amp[a:b] = 1.0
        else:
            f[a:b] = cur
    amp = lp(amp, 6)
    vib = 1 + 0.012 * np.sin(2 * np.pi * 5.6 * tt) * np.clip(tt * 2, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    s = np.sin(ph) + 0.15 * np.sin(2 * ph)
    return s * amp * 0.28


def heartbeat(gain=1.0):
    def thump(f0, dur):
        tt = t_(dur)
        f = f0 * np.exp(-tt * 9) + 38
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 14)
    a = thump(110, 0.35)
    b = thump(90, 0.35) * 0.7
    out = np.zeros(int(0.7 * SR))
    out[:len(a)] += a
    out[int(0.22 * SR):int(0.22 * SR) + len(b)] += b
    knock = bp(rng.standard_normal(len(out)), 150, 900) * np.exp(-np.arange(len(out)) / SR * 30) * 0.35
    k2 = np.roll(knock, int(0.22 * SR)) * 0.7
    return (lp(out, 300) + knock + k2) * gain


def choir(freqs, dur):
    tt = t_(dur)
    src = np.zeros(len(tt))
    for f in freqs:
        for d in (-0.006, 0.0, 0.006):
            vib = 1 + 0.006 * np.sin(2 * np.pi * (4.8 + d * 100) * tt)
            src += 2 * ((np.cumsum(f * (1 + d) * vib) / SR) % 1) - 1
    # "ooh" formants
    s = bp(src, 300, 520) * 1.0 + bp(src, 700, 900) * 0.35 + bp(src, 2400, 2700) * 0.08
    return s / len(freqs) * 0.5 * adsr(len(tt), 1.2, 0.5, 0.9, 1.2)


def tremolo_strings(f, dur):
    tt = t_(dur)
    s = 2 * ((f * tt) % 1) - 1 + 0.4 * rng.standard_normal(len(tt))
    s = bp(s, f * 0.8, min(f * 6, 16000))
    s *= 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 13 * tt))
    return lp(s, 7000) * adsr(len(tt), 1.5, 0.2, 1.0, 1.0) * 0.12


# ------------------------------------------------------------------ score

CHORDS = [("D", ["D", "F", "A"]), ("Bb", ["Bb", "D", "F"]), ("G", ["G", "Bb", "D"]), ("A", ["A", "C#", "E"])]
MEL_A = [["A4", None, "D5", None, "F5", "E5", "D5", "A4"],
         ["F5", None, "D5", None, "Bb4", None, "D5", "C5"],
         ["Bb4", None, "G4", None, "D5", None, "Bb4", "A4"],
         ["C#5", None, "E5", None, "A5", None, "G5", "E5"]]
MEL_B = [["D6", None, "A5", None, "F5", None, "A5", None],
         ["Bb5", None, "F5", None, "D5", None, "F5", None],
         ["G5", None, "D5", None, "Bb4", None, "D5", "E5"],
         ["E5", None, "C#5", None, "A4", None, None, None]]
SECTIONS = [MEL_A, MEL_B, MEL_A, MEL_B]


def transpose(n, semis):
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    midi = 12 * (int(n[-1]) + 1) + NOTE[n[:-1]] + semis
    return names[midi % 12] + str(midi // 12 - 1)


def music_cute():
    buf = np.zeros((int(LOOP * SR), 2))
    e8 = BEAT / 2
    for bar in range(BARS):
        t0 = bar * BAR
        root, triad = CHORDS[bar % 4]
        mel = SECTIONS[bar // 4][bar % 4]
        for i, n in enumerate(mel):
            if n:
                place(buf, music_box(hz(n)), t0 + i * e8, 0.55, pan=0.15)
                if bar >= 8:  # second half: glockenspiel a third above, sparkling
                    harm = transpose(n, 12 if bar % 2 else 4)
                    place(buf, music_box(hz(harm), 1.2, 0.6), t0 + i * e8 + 0.01, 0.16, pan=-0.35)
        # celesta 16th arpeggios, quiet, ping-ponged
        arp = [triad[0] + "4", triad[1] + "4", triad[2] + "4", triad[1] + "5"]
        for k in range(16):
            n = arp[k % 4] if k % 8 < 4 else arp[3 - k % 4]
            place(buf, celesta(hz(n)), t0 + k * BEAT / 4, 0.11 + 0.03 * (k % 4 == 0), pan=-0.5 if k % 2 else 0.5)
        # pizzicato bass on 1 and 3
        place(buf, pluck(hz(root + "2")), t0, 0.5)
        fifth = {"D": "A1", "Bb": "F2", "G": "D2", "A": "E2"}[root]
        place(buf, pluck(hz(fifth)), t0 + 2 * BEAT, 0.42)
        # soft pad
        place(buf, pad([hz(n + "3") for n in triad], BAR + 0.6, cutoff=1100), t0, 0.22)
    buf = reverb(buf, 2.6, 0.32, seed=1, damp=6000)
    return loudness_match(buf, -18.0, 0.85)


def music_scary():
    buf = np.zeros((int(LOOP * SR), 2))
    low = {"D": ["D3", "A3", "D4", "F4"], "Bb": ["Bb2", "F3", "Bb3", "D4"],
           "G": ["G2", "D3", "G3", "Bb3"], "A": ["A2", "E3", "A3", "C#4"]}
    for bar in range(BARS):
        t0 = bar * BAR
        root, triad = CHORDS[bar % 4]
        voicing = [hz(n) for n in low[root]]
        if root == "D" and bar % 8 == 4:
            voicing.append(hz("Eb4"))  # dissonant b2 rub
        # the lullaby, broken: same melody, detuned and sparse (every other note)
        mel = SECTIONS[bar // 4][bar % 4]
        for i, n in enumerate(mel):
            if n and i % 2 == 0:
                place(buf, broken_music_box(hz(n)), t0 + i * BEAT / 2, 0.33, pan=-0.25)
        place(buf, organ(voicing, BAR + 0.5), t0, 0.9)
        # sub bass
        tt = t_(BAR)
        sub = np.sin(2 * np.pi * hz(root + "1") * tt) * adsr(len(tt), 0.05, 0.3, 0.8, 0.3) * 0.35
        place(buf, sub, t0, 1.0)
        # heartbeat: once per bar, twice in the second half
        place(buf, heartbeat(), t0, 0.9)
        if bar >= 8:
            place(buf, heartbeat(0.8), t0 + 2 * BEAT, 0.8)
        # choir from bar 5
        if bar >= 4:
            place(buf, choir([hz(n + "3") for n in triad] + [hz(triad[0] + "4")], BAR + 1.0), t0, 0.5, pan=-0.2)
        # tremolo strings swell in the last 4 bars
        if bar >= 12:
            place(buf, tremolo_strings(hz(triad[0] + "5"), BAR + 0.5), t0, 0.9, pan=0.4)
            place(buf, tremolo_strings(hz(triad[2] + "5") * 1.06, BAR + 0.5), t0, 0.6, pan=-0.4)
    # theremin: melody B, slowed and darkened, over bars 4-7 and 12-15
    for start in (4, 12):
        notes = []
        for bar in range(4):
            mel = MEL_B[bar]
            for i in range(0, 8, 2):
                n = mel[i]
                if n and bar == 2 and i == 4:
                    n = "B4"  # chromatic sour note
                notes.append(transpose(n, -12) if n else None)
        place(buf, theremin(notes, BEAT), start * BAR, 0.9, pan=0.1)
    # boom hits
    for bar in (0, 8):
        tt = t_(2.5)
        boom = lp(rng.standard_normal(len(tt)), 180) * np.exp(-tt * 2.2) * 2.0
        boom += np.sin(2 * np.pi * 45 * tt) * np.exp(-tt * 3) * 0.8
        place(buf, boom, bar * BAR, 0.5)
    buf = reverb(buf, 4.0, 0.38, seed=2, damp=4500)
    return loudness_match(buf, -18.0, 0.85)


# ------------------------------------------------------------------ sfx

def st(x):
    return np.stack([x, x], axis=1)


def with_tail(x, seconds=1.0, wet=0.3, seed=5):
    pad_ = np.zeros((int(seconds * SR), 2))
    y = np.concatenate([st(x) if x.ndim == 1 else x, pad_])
    return reverb(y, seconds, wet, seed=seed)


def fade_out(x, sec=0.05):
    n = int(sec * SR)
    x[-n:] *= np.linspace(1, 0, n)[:, None] if x.ndim == 2 else np.linspace(1, 0, n)
    return x


def sfx_claim_cute():
    out = np.zeros(int(0.9 * SR))
    for i, n in enumerate(["D5", "F5", "A5", "D6", "F6"]):
        s = music_box(hz(n), 0.8, 1.2)
        a = int(i * 0.055 * SR)
        out[a:a + len(s)] += s[: len(out) - a] * (0.9 - i * 0.08)
    tt = t_(0.9)
    shimmer = hp(rng.standard_normal(len(tt)), 7000) * np.exp(-tt * 6) * 0.15
    return fade_out(with_tail(out + shimmer, 0.8, 0.35))


def sfx_claim_scary():
    tt = t_(1.0)
    whoosh = bp(rng.standard_normal(len(tt)), 200, 2400) * np.exp(-((tt - 0.12) ** 2) / 0.02) * 0.8
    whoosh = lp(whoosh, 1500)
    f = 95 * (1 + 0.08 * np.sin(2 * np.pi * 23 * tt)) * np.exp(-tt * 0.6)
    growl = 2 * ((np.cumsum(f) / SR) % 1) - 1
    growl = bp(growl, 120, 900) * adsr(len(tt), 0.05, 0.2, 0.6, 0.4) * 0.9
    thump = np.sin(2 * np.pi * np.cumsum(70 * np.exp(-tt * 8) + 35) / SR) * np.exp(-tt * 9)
    return fade_out(with_tail(softclip(whoosh + growl + thump, 1.8) * 0.8, 1.0, 0.35))


def sfx_trail(cute):
    tt = t_(0.22)
    f0, f1 = (700, 1500) if cute else (180, 90)
    f = f0 + (f1 - f0) * tt / 0.22
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 9)
    if not cute:
        s = lp(s + 0.4 * rng.standard_normal(len(tt)) * np.exp(-tt * 12), 900)
    return fade_out(with_tail(s * 0.6, 0.4, 0.25))


def sfx_snap():
    tt = t_(0.7)
    crack = hp(rng.standard_normal(len(tt)), 2500) * np.exp(-tt * 18)
    pings = sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt * (10 + i * 3)) for i, f in enumerate([2730, 3910, 5170, 6440]))
    thud = np.sin(2 * np.pi * np.cumsum(140 * np.exp(-tt * 12) + 50) / SR) * np.exp(-tt * 10)
    return fade_out(with_tail((crack * 0.7 + pings * 0.12 + thud * 0.8) * 0.8, 0.6, 0.25))


def sfx_bomb():
    tt = t_(1.6)
    boom = lp(rng.standard_normal(len(tt)), 900) * np.exp(-tt * 3.5) * 1.6
    sub = np.sin(2 * np.pi * np.cumsum(90 * np.exp(-tt * 5) + 32) / SR) * np.exp(-tt * 3) * 1.2
    crackle = hp(rng.standard_normal(len(tt)) * (rng.random(len(tt)) > 0.995), 2000) * np.exp(-tt * 2) * 2
    return fade_out(with_tail(softclip(boom + sub + crackle, 2.0) * 0.85, 1.2, 0.3))


def sfx_capture():
    tt = t_(0.5)
    puff = bp(rng.standard_normal(len(tt)), 400, 3000) * np.exp(-tt * 14) * 0.6
    pop = np.sin(2 * np.pi * np.cumsum(500 + 900 * np.clip(tt * 12, 0, 1)) / SR) * np.exp(-tt * 16)
    return fade_out(with_tail(puff + pop * 0.6, 0.5, 0.3))


def sfx_tier_up():
    tt = t_(1.3)
    f = 70 * (1 + tt * 0.8) * (1 + 0.1 * np.sin(2 * np.pi * 28 * tt))
    growl = bp(2 * ((np.cumsum(f) / SR) % 1) - 1, 100, 1200) * adsr(len(tt), 0.1, 0.3, 0.7, 0.5)
    bell = music_box(hz("D4"), 1.3, 2.0) * 0.6 + music_box(hz("Ab4"), 1.3, 2.0) * 0.4
    return fade_out(with_tail(softclip(growl * 1.2 + bell, 1.5) * 0.7, 1.2, 0.35))


def sfx_tier_down():
    tt = t_(1.0)
    purr = lp(rng.standard_normal(len(tt)), 300) * (0.5 + 0.5 * np.sin(2 * np.pi * 24 * tt)) * adsr(len(tt), 0.1, 0.2, 0.8, 0.4)
    chime = music_box(hz("A5"), 1.0) + music_box(hz("D6"), 1.0) * 0.6
    return fade_out(with_tail(purr * 1.2 + chime * 0.7, 0.9, 0.35))


def sfx_win():
    out = np.zeros(int(2.0 * SR))
    for i, n in enumerate(["D5", "F#5", "A5", "D6", "F#6", "A6"]):
        s = music_box(hz(n), 1.6, 1.3)
        a = int(i * 0.11 * SR)
        out[a:a + len(s)] += s[: len(out) - a] * 0.8
    chord = sum(music_box(hz(n), 1.4) for n in ["D5", "F#5", "A5"]) * 0.5
    a = int(0.75 * SR)
    out[a:a + len(chord)] += chord[: len(out) - a]
    return fade_out(with_tail(out * 0.7, 1.5, 0.35))


def sfx_lose():
    out = np.zeros(int(2.2 * SR))
    for i, n in enumerate(["D3", "C#3", "C3", "B2"]):
        s = organ([hz(n), hz(n) * 1.5], 0.6 if i < 3 else 1.4, 0.03, 0.3)
        a = int(i * 0.42 * SR)
        out[a:a + len(s)] += s[: len(out) - a] * 2.5
    tt = t_(2.2)
    out += np.sin(2 * np.pi * np.cumsum(60 * np.exp(-((tt - 1.26).clip(0)) * 5) + 30) / SR) * np.exp(-((tt - 1.26).clip(0)) * 4) * (tt > 1.26) * 0.8
    return fade_out(with_tail(out * 0.8, 1.5, 0.35))


def sfx_click():
    tt = t_(0.07)
    s = bp(rng.standard_normal(len(tt)), 1500, 5000) * np.exp(-tt * 90) + np.sin(2 * np.pi * 1800 * tt) * np.exp(-tt * 70) * 0.5
    return fade_out(st(s * 0.5), 0.01)


def sfx_charm():
    out = np.zeros(int(1.4 * SR))
    for i, n in enumerate(["A6", "E7", "C#7", "A7"]):
        s = music_box(hz(n), 1.2, 0.5)
        a = int(i * 0.04 * SR)
        out[a:a + len(s)] += s[: len(out) - a] * 0.5
    tt = t_(1.4)
    out += hp(rng.standard_normal(len(tt)), 9000) * np.exp(-tt * 3) * 0.08
    return fade_out(with_tail(out, 1.6, 0.5))


def sfx_spawn():
    out = np.zeros(int(0.45 * SR))
    for k in range(3):
        tt = t_(0.06)
        s = np.sin(2 * np.pi * np.cumsum(np.linspace(5200, 2600, len(tt))) / SR) * np.exp(-tt * 40)
        a = int(k * 0.11 * SR)
        out[a:a + len(s)] += s
    return fade_out(with_tail(out * 0.35, 0.5, 0.3))


def sfx_grow():
    tt = t_(0.7)
    f = 28 + 6 * np.sin(2 * np.pi * 3 * tt)
    creak = 2 * ((np.cumsum(f) / SR) % 1) - 1
    creak = bp(creak, 450, 1800) * adsr(len(tt), 0.05, 0.1, 0.8, 0.2)
    return fade_out(with_tail(creak * 0.8, 0.5, 0.3))


def sfx_star(i):
    n = ["A5", "D6", "F#6"][i]
    return fade_out(with_tail(music_box(hz(n), 1.0, 1.4) * 0.8, 0.8, 0.35))


def sfx_start():
    tt = t_(1.4)
    swell = bp(rng.standard_normal(len(tt)), 300, 3000) * np.sin(np.pi * tt / 1.4) ** 2 * 0.3
    gong = sum(np.sin(2 * np.pi * hz("D3") * k * tt) * np.exp(-tt * (1.5 + k)) / k for k in (1, 2.01, 3.03, 4.2))
    return fade_out(with_tail(swell + gong * 0.35, 1.5, 0.4))


if __name__ == "__main__":
    save("music_cute", music_cute(), 4)
    save("music_scary", music_scary(), 4)
    sfx = {
        "sfx_claim_cute": sfx_claim_cute(), "sfx_claim_scary": sfx_claim_scary(),
        "sfx_trail_cute": sfx_trail(True), "sfx_trail_scary": sfx_trail(False),
        "sfx_snap": sfx_snap(), "sfx_bomb": sfx_bomb(), "sfx_capture": sfx_capture(),
        "sfx_tier_up": sfx_tier_up(), "sfx_tier_down": sfx_tier_down(),
        "sfx_win": sfx_win(), "sfx_lose": sfx_lose(), "sfx_click": sfx_click(),
        "sfx_charm": sfx_charm(), "sfx_spawn": sfx_spawn(), "sfx_grow": sfx_grow(),
        "sfx_star1": sfx_star(0), "sfx_star2": sfx_star(1), "sfx_star3": sfx_star(2),
        "sfx_start": sfx_start(),
    }
    for k, v in sfx.items():
        save(k, loudness_match(v, -15.0 if k != "sfx_click" else -18.0, 0.9))
    print("ok", 2 + len(sfx), "audio files")
