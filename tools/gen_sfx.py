"""効果音 8 個(仕様書 §9.12)を合成して assets/sfx/<名前>.wav に書く。標準ライブラリだけ。
雑音は決まった式の擬似乱数(xorshift32)で作るので、何度回しても同じバイト列になる。16bit PCM・モノラル・22050 Hz。合計 300 KB 以下(NFR-7)。
作りは RootCall の tools/gen_sfx.py。

    python tools/gen_sfx.py
"""

import math
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "sfx"
RATE = 22050
TAU = 2 * math.pi


def env(i, n, gain, decay, t):
    return gain * math.exp(-decay * t) * min(1.0, (n - i) / (0.004 * RATE), i / (0.001 * RATE))


def tone(buf, at, dur, f0, f1=None, gain=1.0, decay=0.0, square=False):
    """音 1 本を buf に足す。f0→f1 へ直線で動き、exp(-decay*t) で消える。square なら矩形に近い音(奇数倍音 3 本)。"""
    f1 = f1 or f0
    start = int(at * RATE)
    n = int(dur * RATE)
    while len(buf) < start + n:
        buf.append(0.0)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        s = math.sin(phase)
        if square:
            s += math.sin(3 * phase) / 3 + math.sin(5 * phase) / 5
        buf[start + i] += env(i, n, gain, decay, t) * s
        phase += TAU * (f0 + (f1 - f0) * i / n) / RATE


def noise(buf, at, dur, gain=1.0, decay=0.0, smooth0=0.0, smooth1=None):
    """雑音を足す。smooth は 1 次の低域通過の係数(0 は素通し、1 に近いほどこもる)。smooth0→smooth1 へ動く。"""
    smooth1 = smooth0 if smooth1 is None else smooth1
    start = int(at * RATE)
    n = int(dur * RATE)
    while len(buf) < start + n:
        buf.append(0.0)
    x = 2463534242
    y = 0.0
    for i in range(n):
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= x >> 17
        x ^= (x << 5) & 0xFFFFFFFF
        r = x / 0xFFFFFFFF * 2 - 1
        a = smooth0 + (smooth1 - smooth0) * i / n
        y = a * y + (1 - a) * r
        buf[start + i] += env(i, n, gain, decay, i / RATE) * y


def write(name, buf, peak):
    top = max(abs(x) for x in buf) or 1.0
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x / top * peak * 32767)) for x in buf))


def main():
    b = []
    noise(b, 0, 0.16, decay=14, smooth0=0.95, smooth1=0.6)  # 突進: 風を切る音
    write("dash", b, 0.45)
    b = []
    tone(b, 0, 0.07, 1760, 1500, decay=40)
    noise(b, 0, 0.03, gain=0.4, decay=80)  # 斬った印: 短い高い音(1 体ごとに半音上げて鳴らす)
    write("cut", b, 0.4)
    b = []
    noise(b, 0, 0.28, decay=12, smooth0=0.2, smooth1=0.7)
    tone(b, 0, 0.22, 660, 520, gain=0.6, decay=14)
    tone(b, 0, 0.22, 990, 780, gain=0.4, decay=16)  # 割れる音(つなぎ 1 ごとに半音上げて鳴らす)
    write("shatter", b, 0.7)
    b = []
    noise(b, 0, 0.2, decay=10, smooth0=0.97)
    tone(b, 0, 0.18, 160, 110, gain=0.6, decay=10)  # 外した突進: 低い空振り
    write("whiff", b, 0.5)
    b = []
    tone(b, 0, 0.08, 140, square=True, decay=12)  # 回数が無い: 低く短い音
    write("empty", b, 0.45)
    b = []
    tone(b, 0, 0.25, 110, 70, square=True, decay=8)
    noise(b, 0, 0.08, gain=0.8, decay=40, smooth0=0.5)  # 当たった: 低い打撃
    write("hurt", b, 0.75)
    b = []
    tone(b, 0, 0.06, 1320, decay=30)
    tone(b, 0.08, 0.06, 1320, decay=30)  # 撃つ予告: 小さい音
    write("warn", b, 0.25)
    b = []
    for k, f in enumerate([784, 659, 523, 392]):
        tone(b, k * 0.1, 0.3, f, decay=7)  # 終わり
    write("over", b, 0.6)
    total = sum(p.stat().st_size for p in OUT.glob("*.wav"))
    print(f"{len(list(OUT.glob('*.wav')))} 個、合計 {total:,} バイト")


if __name__ == "__main__":
    main()
