"""Gera PNGs de interface (mascaras, sombras, degrades) sem dependencias."""
import math, struct, sys, zlib

OUT = sys.argv[1]


def save_png(path, w, h, pixel):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            raw.extend(pixel(x, y))
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    open(f"{OUT}/{path}", "wb").write(png)


def rrect_dist(x, y, w, h, r):
    """Distancia com sinal ao retangulo arredondado [0,w]x[0,h] (negativa dentro)."""
    qx = abs(x - w / 2) - (w / 2 - r)
    qy = abs(y - h / 2) - (h / 2 - r)
    return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r


def mask(path, w, h, r):
    def px(x, y):
        a = min(max(0.5 - rrect_dist(x + 0.5, y + 0.5, w, h, r), 0), 1)
        return (255, 255, 255, int(a * 255))
    save_png(path, w, h, px)


def shadow(path, w, h, r, blur, strength):
    W, H = w + 2 * blur, h + 2 * blur
    def px(x, y):
        d = rrect_dist(x + 0.5 - blur, y + 0.5 - blur, w, h, r)
        t = 1 if d <= 0 else max(0, 1 - d / blur)
        return (0, 0, 0, int(strength * (t * t * (3 - 2 * t)) * 255))
    save_png(path, W, H, px)


def sheen(path, w, h, r):
    def px(x, y):
        inside = min(max(0.5 - rrect_dist(x + 0.5, y + 0.5, w, h, r), 0), 1)
        t = max(0, 1 - y / (h * 0.55))
        return (255, 255, 255, int(inside * 0.28 * t * t * 255))
    save_png(path, w, h, px)


def border(path, w, h, r, stroke, alpha):
    """Contorno fino do retangulo arredondado (destaca icones de fundo escuro)."""
    def px(x, y):
        d = rrect_dist(x + 0.5, y + 0.5, w, h, r)
        a = min(max(stroke / 2 + 0.5 - abs(d + stroke / 2), 0), 1)
        return (255, 255, 255, int(a * alpha * 255))
    save_png(path, w, h, px)


def vgrad(path, w, h, stops):
    def px(x, y):
        t = y / (h - 1)
        for (t0, a0), (t1, a1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                a = a0 + (a1 - a0) * (t - t0) / (t1 - t0)
                break
        return (0, 0, 0, int(a * 255))
    save_png(path, w, h, px)


def hgrad(path, w, h, a0, a1):
    save_png(path, w, h, lambda x, y: (0, 0, 0, int((a0 + (a1 - a0) * x / (w - 1)) * 255)))


mask("tile_mask.png", 250, 188, 22)
sheen("tile_sheen.png", 250, 188, 22)
shadow("tile_shadow.png", 250, 188, 22, 34, 0.75)
mask("hero_mask.png", 520, 390, 34)
shadow("hero_shadow.png", 520, 390, 34, 50, 0.8)
vgrad("fade_bottom.png", 8, 270, [(0, 0.0), (0.5, 0.15), (1, 0.45)])
hgrad("fade_left.png", 240, 8, 0.45, 0.0)

mask("pill.png", 190, 64, 32)
border("tile_border.png", 250, 188, 22, 2.5, 0.35)
border("hero_border.png", 520, 390, 34, 3, 0.30)


def ninepatch(path, w, h, stretch, px):
    """PNG 9-patch (.9.png): cantos fixos e centro esticavel em qualquer tamanho."""
    s0, s1 = stretch
    def full(x, y):
        if y == 0:
            return (0, 0, 0, 255) if 0 < x <= w and s0 <= x - 1 < s1 else (0, 0, 0, 0)
        if x == 0:
            return (0, 0, 0, 255) if 0 < y <= h and s0 <= y - 1 < s1 else (0, 0, 0, 0)
        if x == w + 1 or y == h + 1:
            return (0, 0, 0, 0)
        return px(x - 1, y - 1)
    save_png(path, w + 2, h + 2, full)


def np_fill(path, r, alpha=1.0):
    size = 2 * r + 4
    def px(x, y):
        a = min(max(0.5 - rrect_dist(x + 0.5, y + 0.5, size, size, r), 0), 1)
        return (255, 255, 255, int(a * alpha * 255))
    ninepatch(path, size, size, (r, r + 4), px)


def np_border(path, r, stroke, alpha):
    size = 2 * r + 4
    def px(x, y):
        d = rrect_dist(x + 0.5, y + 0.5, size, size, r)
        a = min(max(stroke / 2 + 0.5 - abs(d + stroke / 2), 0), 1)
        return (255, 255, 255, int(a * alpha * 255))
    ninepatch(path, size, size, (r, r + 4), px)


def np_shadow(path, r, blur, strength):
    size = 2 * (r + blur) + 4
    inner = size - 2 * blur
    def px(x, y):
        d = rrect_dist(x + 0.5 - blur, y + 0.5 - blur, inner, inner, r)
        t = 1 if d <= 0 else max(0, 1 - d / blur)
        return (0, 0, 0, int(strength * (t * t * (3 - 2 * t)) * 255))
    ninepatch(path, size, size, (r + blur, r + blur + 4), px)


np_fill("panel.9.png", 34)
np_border("panel_edge.9.png", 34, 2, 0.12)
np_shadow("panel_shadow.9.png", 34, 60, 0.6)
np_fill("row.9.png", 16)
mask("thumb_mask.png", 128, 96, 16)
mask("small_mask.png", 72, 54, 10)
def puff(path, size):
    """Nuvenzinha de poeira: circulo suave."""
    c = size / 2
    def px(x, y):
        d = math.hypot(x + 0.5 - c, y + 0.5 - c) / c
        a = max(0, 1 - d) ** 1.6
        return (235, 228, 215, int(a * 0.85 * 255))
    save_png(path, size, size, px)


puff("dust.png", 48)
print("ok")
