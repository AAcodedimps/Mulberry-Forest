"""Synthesizes every sound effect and the two music loops for Mulberry Forest.
Everything is generated from scratch here (sine waves, filtered noise, simple reverb), so there
are no outside recordings and no licences to track. Output: 16-bit mono PCM .raw files + manifest."""
import json, os, sys
import numpy as np
from scipy.signal import butter, lfilter

SR = 22050
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)
manifest = {}


def t_of(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=None, shape=6.0):
    """attack then exponential release over the whole length"""
    e = np.ones(n)
    na = max(1, int(a * SR))
    e[:na] = np.linspace(0, 1, na)
    tail = np.arange(n - na) / max(1, n - na)
    e[na:] = np.exp(-shape * tail)
    return e


def lp(x, f, order=2):
    b, a = butter(order, min(f / (SR / 2), 0.99), 'low')
    return lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = butter(order, f / (SR / 2), 'high')
    return lfilter(b, a, x)


def bp(x, f1, f2, order=2):
    b, a = butter(order, [f1 / (SR / 2), min(f2 / (SR / 2), 0.99)], 'band')
    return lfilter(b, a, x)


def sweep(f0, f1, d, curve=1.0):
    t = t_of(d)
    k = (t / d) ** curve
    f = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def bell(f, d, decay=5.0, partials=((1, 1), (2.76, 0.35), (5.4, 0.12))):
    t = t_of(d)
    s = sum(a * np.sin(2 * np.pi * f * m * t) * np.exp(-decay * m ** 0.5 * t) for m, a in partials)
    return s * env(len(t), 0.002, shape=1.0)


def reverb(x, mix=0.25, length=1.2, wrap=False):
    """small Schroeder reverb (comb + allpass); wrap=True folds the tail onto the start (for loops)"""
    n = len(x)
    pad = int(length * SR)
    y = np.concatenate([x, np.zeros(pad)])
    wet = np.zeros_like(y)
    for dl, g in [(0.0297, 0.80), (0.0371, 0.78), (0.0411, 0.76), (0.0437, 0.74)]:
        d = int(dl * SR)
        a = np.zeros(d + 1); a[0] = 1.0; a[d] = -g          # comb: y[n] = x[n] + g*y[n-d]
        wet += lfilter([1.0], a, y)
    wet /= 4
    for dl, g in [(0.005, 0.7), (0.0017, 0.7)]:
        d = int(dl * SR)
        b = np.zeros(d + 1); b[0] = -g; b[d] = 1.0           # allpass
        a = np.zeros(d + 1); a[0] = 1.0; a[d] = -g
        wet = lfilter(b, a, wet)
    wet = lp(wet, 3500)
    res = (1 - mix) * y + mix * wet
    if wrap:
        body = res[:n].copy()
        body[:pad] += res[n:n + pad]
        return body
    return res


def fade(x, fin=0.003, fout=0.02):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def save(name, x, peak_db=-4.0, loop=False, kind="sfx"):
    x = np.asarray(x, dtype=np.float64)
    if not loop:
        x = fade(x)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * (10 ** (peak_db / 20))
    pcm = np.clip(x * 32767, -32768, 32767).astype('<i2')
    pcm.tofile(os.path.join(OUT, name + '.raw'))
    manifest[name] = {"loop": loop, "samples": len(pcm), "seconds": round(len(pcm) / SR, 3), "kind": kind}


# ------------------------------------------------------------------ sound effects
# jump: a soft little upward "hup" with a breath of air
t = t_of(0.16)
x = sweep(380, 760, 0.16, 0.6) * env(len(t), 0.004, shape=5) * 0.7 + lp(noise(0.16), 2500) * env(len(t), 0.002, shape=10) * 0.25
save('jump', x, -9)

# land: a muffled thud on moss
t = t_of(0.18)
x = np.sin(2 * np.pi * np.cumsum(np.linspace(140, 60, len(t))) / SR) * env(len(t), 0.002, shape=9) + lp(noise(0.18), 700) * env(len(t), 0.001, shape=14) * 0.8
save('land', x, -10)

# pick up a stone: two glassy taps
x = np.concatenate([bell(1350, 0.09, 30), bell(1900, 0.2, 18)]) * 0.8
save('pickup_stone', x, -9)

# pick up a power: a rising sparkle arpeggio
notes = [784, 988, 1175, 1568]
x = np.zeros(int(SR * 0.75))
for i, f in enumerate(notes):
    s = bell(f, 0.5, 6)
    o = int(i * 0.07 * SR)
    x[o:o + len(s)] += s * (0.8 if i < 3 else 1.0)
x = reverb(x, 0.3, 0.6)
save('pickup_power', x, -7)

# Wild Berries cure: a warm, gentle two-note chime
x = np.zeros(int(SR * 0.7))
for i, f in enumerate([659, 880]):
    s = bell(f, 0.55, 5, ((1, 1), (2, 0.25), (3, 0.08)))
    o = int(i * 0.1 * SR)
    x[o:o + len(s)] += s
save('pickup_cure', reverb(x, 0.3, 0.6), -8)

# throw: a quick whoosh of air
d = 0.22
n = noise(d)
x = np.zeros_like(n)
for i, (f0, f1) in enumerate([(500, 900), (900, 1600), (1600, 2600)]):
    x += bp(n, f0, f1) * np.sin(np.pi * np.clip((t_of(d) - i * 0.02) / 0.18, 0, 1)) ** 2
save('throw', x, -10)

# stone hits a ghost: a hollow bonk with a ghostly ring
t = t_of(0.45)
x = np.sin(2 * np.pi * np.cumsum(np.linspace(420, 260, len(t))) / SR) * env(len(t), 0.001, shape=12)
x += bell(980, 0.45, 7, ((1, 0.6), (1.5, 0.3), (2.3, 0.15)))
x += lp(noise(0.45), 1800) * env(len(t), 0.001, shape=30) * 0.6
save('ghost_hit', reverb(x, 0.25, 0.5), -6)

# a killer ghost rises: a low, wavering moan with a cold breath
d = 1.4
t = t_of(d)
f = 170 + 120 * (t / d) ** 0.7 + 9 * np.sin(2 * np.pi * 5.5 * t)
x = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR)
x *= np.sin(np.pi * t / d) ** 1.3
x += bp(noise(d), 300, 1400) * np.sin(np.pi * t / d) ** 2 * 0.5
x += np.sin(2 * np.pi * 55 * t) * env(len(t), 0.01, shape=3) * 0.6
save('ghost_rise', reverb(x, 0.35, 0.9), -5)

# a mischief ghost rises: a playful, rising giggle-whistle
d = 0.9
t = t_of(d)
f = 520 + 380 * (t / d) + 60 * np.sin(2 * np.pi * 11 * t)
x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / d) ** 1.2 * 0.8
for i in range(3):
    s = bell(1300 + i * 260, 0.25, 12)
    o = int((0.35 + i * 0.12) * SR)
    x[o:o + len(s)] += s * 0.5
save('mischief_rise', reverb(x, 0.3, 0.6), -7)

# caught by a killer ghost: a sharp metallic stab and a deep, dark hit
d = 1.3
t = t_of(d)
x = bp(noise(d), 2500, 7000) * env(len(t), 0.001, shape=25) * 0.7
x += sum(np.sin(2 * np.pi * f * t) * np.exp(-3.5 * t) * a for f, a in [(98, 1), (103.8, 0.8), (146.8, 0.5), (233, 0.3)])
x += np.sin(2 * np.pi * np.cumsum(np.linspace(900, 300, len(t))) / SR) * env(len(t), 0.001, shape=14) * 0.4
save('caught', reverb(x, 0.35, 1.0), -3)

# trip over a trunk: a stumble (two scuffs and a bump)
x = np.zeros(int(SR * 0.4))
for o, f in [(0.0, 900), (0.09, 700)]:
    s = bp(noise(0.08), f * 0.6, f * 1.4) * env(int(SR * 0.08), 0.002, shape=8)
    x[int(o * SR):int(o * SR) + len(s)] += s * 0.6
t = t_of(0.2)
bump = np.sin(2 * np.pi * np.cumsum(np.linspace(180, 70, len(t))) / SR) * env(len(t), 0.002, shape=8)
x[int(0.18 * SR):int(0.18 * SR) + len(bump)] += bump
save('trip', x, -7)

# fall into a hole: a falling whistle swallowed by the dark, then a soft thump
d = 0.75
t = t_of(d)
x = np.sin(2 * np.pi * np.cumsum(900 * (1 - 0.8 * (t / d) ** 0.8)) / SR) * (1 - t / d) ** 1.5 * 0.7
x += lp(noise(d), 900) * (t / d) * 0.25
th = np.sin(2 * np.pi * 60 * t_of(0.25)) * env(int(SR * 0.25), 0.002, shape=8)
x = np.concatenate([x, th])
save('fall', reverb(x, 0.3, 0.6), -5)

# the tree shakes: a rustle of leaves
d = 0.6
t = t_of(d)
flutter = 0.55 + 0.45 * np.sin(2 * np.pi * 17 * t) * np.sin(2 * np.pi * 3 * t)
x = bp(noise(d), 1500, 6000) * flutter * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 0.8
x += lp(noise(d), 400) * 0.3 * env(len(t), 0.01, shape=6)
save('tree_shake', x, -9)

# a berry drops into the basket: a little "plip" and a soft wicker tap
t = t_of(0.3)
x = np.sin(2 * np.pi * np.cumsum(np.linspace(1250, 480, len(t)) ** 1.0) / SR) * env(len(t), 0.001, shape=14) * 0.8
tap = bp(noise(0.05), 1200, 3500) * env(int(SR * 0.05), 0.001, shape=10) * 0.5
x[int(0.08 * SR):int(0.08 * SR) + len(tap)] += tap
x += bell(1760, 0.3, 10) * 0.35
save('berry', x, -8)

# bees buzzing (seamless 1-second loop: every pitch fits a whole number of cycles)
t = t_of(1.0)
x = np.zeros_like(t)
for f, a, vib in [(220, 1.0, 7), (229, 0.8, 9), (447, 0.35, 8), (211, 0.6, 6)]:
    ph = 2 * np.pi * f * t + 0.12 * np.sin(2 * np.pi * vib * t)
    saw = sum(np.sin(k * ph) / k for k in range(1, 8))
    x += a * saw
x *= 0.75 + 0.25 * np.sin(2 * np.pi * 4 * t)
x = lp(np.tile(x, 3), 1800)[len(t):2 * len(t)]   # filter in the middle copy so the ends meet
save('bees', x, -10, loop=True)

# the stone gate opens: a deep grinding rumble and a rising magical chord
d = 2.6
t = t_of(d)
rumble = lp(noise(d), 160, 3) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t)) * np.sin(np.pi * np.clip(t / 1.6, 0, 1)) * 2.0
chord = np.zeros_like(t)
for i, f in enumerate([293.7, 370, 440, 587.3, 740]):
    s = np.sin(2 * np.pi * f * t) * np.clip((t - 0.5 - i * 0.15) / 0.5, 0, 1) * np.exp(-1.2 * np.clip(t - 1.2, 0, None))
    chord += s * 0.35
x = rumble + chord
save('gate_open', reverb(x, 0.35, 1.2), -4)

# the sealed gate refuses you: a low stone thunk
t = t_of(0.3)
x = np.sin(2 * np.pi * 75 * t) * env(len(t), 0.002, shape=10) + lp(noise(0.3), 500) * env(len(t), 0.001, shape=20) * 0.6
save('gate_deny', x, -8)

# squash a ghost by jumping on it: a soft "pomf"
t = t_of(0.3)
x = np.sin(2 * np.pi * np.cumsum(np.linspace(300, 120, len(t))) / SR) * env(len(t), 0.002, shape=10)
x += lp(noise(0.3), 1500) * env(len(t), 0.001, shape=18) * 0.5
save('squash', x, -7)

# trunk smashed with Strength Fig: a woody crack
t = t_of(0.4)
x = hp(noise(0.4), 800) * env(len(t), 0.001, shape=25) + np.sin(2 * np.pi * 110 * t) * env(len(t), 0.002, shape=10) * 0.7
save('smash', x, -6)

# Bark Shield blocks a hit: a wooden "tok"
t = t_of(0.2)
x = bell(620, 0.2, 18, ((1, 1), (2.1, 0.3))) + bp(noise(0.2), 600, 2000) * env(len(t), 0.001, shape=30) * 0.4
save('shield', x, -8)

# menu buttons: a tiny soft tick
x = bell(1500, 0.07, 40) * 0.8
save('ui_click', x, -12)

# escaped: a short happy phrase
x = np.zeros(int(SR * 2.4))
for i, (f, o) in enumerate([(587.3, 0.0), (740, 0.18), (880, 0.36), (1174.7, 0.6), (1108.7, 0.9), (1174.7, 1.15)]):
    s = bell(f, 1.1, 3.5, ((1, 1), (2, 0.2), (3, 0.06)))
    x[int(o * SR):int(o * SR) + len(s)] += s
save('win', reverb(x, 0.35, 1.0), -6)

# ------------------------------------------------------------------ music
BPM = 66.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = 8
LOOP = BAR * BARS          # about 29 seconds


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def pad_note(f, d):
    t = t_of(d)
    x = np.zeros_like(t)
    for det in (-0.6, 0.0, 0.7):
        ff = f * 2 ** (det / 1200 * 8)
        x += np.sin(2 * np.pi * ff * t) + 0.18 * np.sin(2 * np.pi * 2 * ff * t)
    a = np.clip(t / 1.2, 0, 1) ** 1.5
    r = np.clip((d - t) / 1.4, 0, 1)
    return x * a * r


def pluck(f, d=1.6):
    t = t_of(d)
    return (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-6 * t)
            + 0.1 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-9 * t)) * np.exp(-3.2 * t) * env(len(t), 0.003, shape=0.01)


# calm: soft pads with a slow kalimba-like melody, D major / B minor
chords = [  # (bass, pad notes)
    (38, [62, 66, 69, 73]),   # Dmaj7
    (35, [59, 62, 66, 69]),   # Bm7
    (43, [59, 62, 67, 71]),   # Gmaj7
    (45, [61, 64, 69, 71]),   # A add9
    (38, [62, 66, 69, 76]),
    (40, [59, 64, 67, 71]),   # Em7
    (43, [62, 67, 71, 74]),
    (45, [61, 64, 69, 73]),
]
N = int(LOOP * SR)
calm = np.zeros(N + int(SR * 4))
for b, (bass, notes) in enumerate(chords):
    o = int(b * BAR * SR)
    seg = sum(pad_note(midi(m), BAR + 1.4) for m in notes) * 0.18
    seg += pad_note(midi(bass), BAR + 1.4) * 0.35
    calm[o:o + len(seg)] += seg
melody = [  # (bar, beat, midi note)
    (0, 0, 74), (0, 1.5, 76), (0, 2.5, 78), (1, 0, 74), (1, 2, 71), (2, 0, 74), (2, 1.5, 79), (2, 3, 78),
    (3, 0, 76), (3, 2, 73), (4, 0, 78), (4, 1.5, 76), (4, 2.5, 74), (5, 0, 71), (5, 2, 76), (6, 0, 79),
    (6, 1, 78), (6, 2, 74), (7, 0, 76), (7, 2.5, 73)]
for bar, beat, m in melody:
    o = int((bar * BAR + beat * BEAT) * SR)
    s = pluck(midi(m)) * 0.32
    calm[o:o + len(s)] += s
# soft wind underneath
calm[:N] += lp(noise(LOOP), 500) * 0.04
calm_loop = calm[:N].copy()
calm_loop[:len(calm) - N] += calm[N:]          # fold the tails back to the start
calm_loop = reverb(calm_loop, 0.35, 2.0, wrap=True)
save('music_calm', lp(calm_loop, 5000), -12, loop=True, kind="music")

# tense layer (same length, so it stays in step): a low pulse like a heartbeat, a cold
# tremolo shimmer and a rub between D and E-flat
XF = int(SR * 1.0)
t = np.arange(N + XF) / SR
tense = np.zeros(N + XF)
drone = (np.sin(2 * np.pi * midi(38) * t) + 0.6 * np.sin(2 * np.pi * midi(39) * t) + 0.3 * np.sin(2 * np.pi * midi(26) * t))
tense += drone * 0.35
beat_t = np.mod(t, BEAT)
pulse = np.exp(-beat_t * 14) + 0.6 * np.exp(-np.clip(beat_t - 0.22, 0, None) * 14) * (beat_t > 0.22)
tense += np.sin(2 * np.pi * 55 * t) * pulse * 0.9
shimmer = (np.sin(2 * np.pi * midi(86) * t) + np.sin(2 * np.pi * midi(87) * t)) * (0.5 + 0.5 * np.sin(2 * np.pi * (BPM / 60 * 4) * t))
tense += shimmer * 0.06
tense = lp(reverb(tense, 0.3, 1.5)[:N + XF], 4000)
# crossfade the end into the start so the loop point is seamless
w = np.sin(np.linspace(0, np.pi / 2, XF))
loop_t = tense[:N].copy()
loop_t[:XF] = tense[:XF] * w + tense[N:N + XF] * np.cos(np.linspace(0, np.pi / 2, XF))
tense = loop_t
save('music_tense', tense, -12, loop=True, kind="music")

with open(os.path.join(OUT, 'manifest.json'), 'w') as f:
    json.dump(manifest, f, indent=1)
for k, v in manifest.items():
    print('%-15s %6.2fs %s' % (k, v['seconds'], 'loop' if v['loop'] else ''))
