#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""程序化生成键盘键音（原创、免版权）。
输出 Keyboard/Sounds/1_normal.wav（普通键音）与 2_delete.wav（删除键音）。
单声道 16-bit PCM / 48 kHz / ~40ms，短促、带快速衰减包络（避免爆音）。
用法：python tools/gen_keysounds.py  （在仓库根运行）
"""
import math
import os
import struct
import wave

SR = 48000
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Keyboard", "Sounds")


def synth(freq, dur, decay, amp, path, harmonics=((1, 1.0),)):
    n = int(SR * dur)
    samples = []
    attack = max(1, int(SR * 0.002))  # 2ms 起音，防爆音
    peak = 0.0
    buf = [0.0] * n
    for i in range(n):
        t = i / SR
        env = math.exp(-t / decay)
        if i < attack:
            env *= i / attack
        s = 0.0
        for k, w in harmonics:
            s += w * math.sin(2 * math.pi * freq * k * t)
        v = s * env
        buf[i] = v
        if abs(v) > peak:
            peak = abs(v)
    if peak <= 0:
        peak = 1.0
    frames = bytearray()
    for v in buf:
        iv = int(max(-1.0, min(1.0, v / peak * amp)) * 32767)
        frames += struct.pack("<h", iv)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    # 普通键：明亮、极短促的轻「嗒」
    synth(1700, 0.035, 0.010, 0.45, os.path.join(OUT_DIR, "1_normal.wav"),
          harmonics=((1, 1.0), (2, 0.35)))
    # 删除键：略低沉、稍长一点的「笃」
    synth(820, 0.045, 0.013, 0.50, os.path.join(OUT_DIR, "2_delete.wav"),
          harmonics=((1, 1.0), (2, 0.25)))
    print("generated:", os.path.join(OUT_DIR, "1_normal.wav"), os.path.join(OUT_DIR, "2_delete.wav"))


if __name__ == "__main__":
    main()
