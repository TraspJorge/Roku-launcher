"""Gera os efeitos sonoros do Meu Menu (WAV mono 16 bits), sem dependencias.

Uso: python3 gerar_sons.py <pasta sounds do app>
"""
import math
import struct
import sys
import wave

OUT = sys.argv[1]
RATE = 44100


def save(name, samples):
    with wave.open(f"{OUT}/{name}", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))


def plum(f_start, f_end, glide, attack, decay, length, gain):
    """Tom puro com queda de afinacao (efeito 'gota'), ataque macio e cauda suave."""
    out = []
    phase = 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        freq = f_end + (f_start - f_end) * math.exp(-t / glide)
        phase += 2 * math.pi * freq / RATE
        env = (1 - math.exp(-t / attack)) * math.exp(-t / decay)
        fade = min(1, (length - t) / 0.01)  # evita estalo no final
        out.append((math.sin(phase) + 0.12 * math.sin(2 * phase)) * env * fade * gain)
    return out


def tick():
    """Mover o foco: 'plum' curto e leve."""
    return plum(f_start=300, f_end=210, glide=0.025, attack=0.006, decay=0.06, length=0.2, gain=0.75)


def pop():
    """Selecionar: 'plum' mais grave e redondo."""
    return plum(f_start=260, f_end=165, glide=0.04, attack=0.008, decay=0.11, length=0.34, gain=0.8)


save("move.wav", tick())
save("select.wav", pop())
print("ok")
