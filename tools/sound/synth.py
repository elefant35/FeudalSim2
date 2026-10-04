"""Synthesizes FeudalSim2's original sound effects (the ones the CC0 packs don't cover).

Run: python3 tools/sound/synth.py <out_dir>   (writes .wav files; build_sounds.sh converts them)
Needs numpy only.
"""
import sys, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(7)
out = sys.argv[1]


def save(name, x):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = np.clip(x / peak * 0.85, -1, 1)
    with wave.open(f"{out}/{name}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def lowpass(x, a):
    """One-pole low-pass; a in (0,1), smaller = darker."""
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def highpass(x, a):
    return x - lowpass(x, a)


def env(n, attack, decay_power=2.0):
    t = np.linspace(0, 1, n)
    a = np.minimum(1, t / max(attack, 1e-4))
    return a * (1 - t) ** decay_power


def grains(sec, count, click_len=0.004, a=0.5):
    """Many tiny clicks scattered in time: seed or grain falling."""
    x = np.zeros(int(SR * sec))
    for _ in range(count):
        t = int(rng.beta(1.5, 3) * (len(x) - SR * click_len))
        n = int(SR * click_len * rng.uniform(0.5, 1.5))
        x[t:t + n] += highpass(rng.uniform(-1, 1, n), a) * env(n, 0.05, 3) * rng.uniform(0.3, 1.0)
    return x


# Sowing: a soft whoosh of the hand plus a patter of seed landing.
for i in range(3):
    n = int(SR * 0.5)
    sweep = lowpass(rng.uniform(-1, 1, n), 0.08) * env(n, 0.3, 1.5) * 0.4
    patter = np.concatenate([np.zeros(int(SR * 0.25)), grains(0.6, 140, 0.003, 0.6)])
    x = np.zeros(len(patter))
    x[:len(sweep)] += sweep
    x += patter * 0.6
    save(f"sow_{i + 1}", x)

# Grain pouring into a sack/basket.
g1 = grains(1.2, 600, 0.003, 0.5)
save("grain_1", g1 * np.linspace(1, 0.3, len(g1)))

# Sickle / swing whoosh: band-passed noise with a pitch-like sweep.
for i in range(3):
    n = int(SR * 0.32)
    x = rng.uniform(-1, 1, n)
    a = np.linspace(0.05, 0.35, n) if i % 2 else np.linspace(0.3, 0.06, n)
    y = np.empty(n)
    acc = 0.0
    for k in range(n):
        acc += a[k] * (x[k] - acc)
        y[k] = acc
    save(f"swish_{i + 1}", highpass(y, 0.02) * env(n, 0.4, 1.2))

# Basket toss: a whoosh up and grain falling back.
w = lowpass(rng.uniform(-1, 1, int(SR * 0.4)), 0.15) * env(int(SR * 0.4), 0.5, 1.5)
g = grains(0.8, 220, 0.003, 0.55) * 0.5
x = np.zeros(int(SR * 1.1))
x[:len(w)] += w
x[int(SR * 0.3):int(SR * 0.3) + len(g)] += g
save("toss_1", x)

# Eating: a few crunchy bites.
for i in range(3):
    x = np.zeros(int(SR * 0.9))
    for b in range(3):
        t = int(SR * (0.05 + b * 0.27 + rng.uniform(0, 0.04)))
        n = int(SR * 0.09)
        x[t:t + n] += lowpass(rng.uniform(-1, 1, n), 0.35) * env(n, 0.02, 2.5) * rng.uniform(0.6, 1.0)
        x[t:t + n] += grains(n / SR, 25, 0.002, 0.5)[:n] * 0.4
    save(f"eat_{i + 1}", x)

# Wing flaps.
x = np.zeros(int(SR * 0.8))
for k in range(6):
    t = int(SR * k * 0.12)
    n = int(SR * 0.08)
    x[t:t + n] += lowpass(rng.uniform(-1, 1, n), 0.06) * env(n, 0.3, 2) * (1 - k / 8)
save("flap_1", x)

# Countryside ambience: soft wind with distant birdsong, 40 s, loops cleanly.
sec = 40
n = SR * sec
wind = lowpass(lowpass(rng.uniform(-1, 1, n), 0.01), 0.05)
swell = 0.6 + 0.4 * np.sin(np.linspace(0, 2 * np.pi * 3, n)) * np.sin(np.linspace(0, 2 * np.pi * 7, n))
x = wind * swell * 3.0
t_all = np.arange(n) / SR
for _ in range(38):
    start = rng.uniform(0, sec - 2)
    notes = rng.integers(2, 6)
    base = rng.uniform(2400, 4200)
    for j in range(notes):
        t0 = start + j * rng.uniform(0.09, 0.16)
        dur = rng.uniform(0.05, 0.12)
        i0, i1 = int(t0 * SR), int((t0 + dur) * SR)
        tt = t_all[i0:i1] - t0
        f = base * (1 + 0.25 * np.sin(2 * np.pi * rng.uniform(15, 30) * tt)) * (1 + rng.uniform(-0.15, 0.25) * tt / dur)
        ph = 2 * np.pi * np.cumsum(f) / SR
        x[i0:i1] += np.sin(ph) * env(i1 - i0, 0.15, 1.5) * rng.uniform(0.03, 0.09)
# Crossfade the ends so the loop is seamless.
fade = SR * 2
x[:fade] = x[:fade] * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
save("ambience_day", x[:-fade])
print("synth done")
