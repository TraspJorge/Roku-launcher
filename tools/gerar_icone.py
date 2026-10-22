"""Gera o icone do Meu Menu (tela inicial da Roku) e a tela de abertura, sem dependencias.

Uso: python3 gerar_icone.py <pasta images do app>
"""
import math
import struct
import sys
import zlib

OUT = sys.argv[1]

# Visual minimalista: fundo preto e quadrados apenas contornados (tracos brancos)
BG = (0, 0, 0)
STROKE = (235, 235, 240)


def save_png(path, w, h, rows):
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(f"{OUT}/{path}", "wb").write(png)


def rrect_dist(x, y, cx, cy, hw, hh, r):
    qx = abs(x - cx) - (hw - r)
    qy = abs(y - cy) - (hh - r)
    return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def render(path, w, h, icon_size):
    """icon_size: altura da grade em pixels; a grade fica centralizada."""
    tile = icon_size * 0.44
    gap = icon_size * 0.12
    radius = tile * 0.24
    grid_w = 3 * tile + 2 * gap
    grid_h = 2 * tile + gap
    ox = (w - grid_w) / 2
    oy = (h - grid_h) / 2
    centers = []
    for i in range(6):
        cx = ox + (i % 3) * (tile + gap) + tile / 2
        cy = oy + (i // 3) * (tile + gap) + tile / 2
        centers.append((cx, cy))
    stroke = max(1.5, tile * 0.055)

    rows = []
    for y in range(h):
        row = bytearray()
        for x in range(w):
            px, py = x + 0.5, y + 0.5
            color = BG
            # So calcula os quadrados perto da grade (acelera a tela de abertura)
            if ox - stroke < px < ox + grid_w + stroke and oy - stroke < py < oy + grid_h + stroke:
                for cx, cy in centers:
                    d = rrect_dist(px, py, cx, cy, tile / 2, tile / 2, radius)
                    cover = min(max(stroke / 2 + 0.5 - abs(d), 0), 1)
                    if cover > 0:
                        color = mix(color, STROKE, cover)
            row.extend(int(min(max(v, 0), 255)) for v in color)
        rows.append(row)
    save_png(path, w, h, rows)


def intro_tiles(icon_size=300):
    """Quadradinhos da abertura animada, com a mesma geometria da tela de abertura (splash)."""
    tile = icon_size * 0.44
    radius = tile * 0.24
    stroke = max(1.5, tile * 0.055)
    size = int(math.ceil(tile + stroke + 4))
    c = size / 2
    for nome, preenchido in (("intro_tile_outline.png", False),):
        raw = bytearray()
        for y in range(size):
            raw.append(0)
            for x in range(size):
                d = rrect_dist(x + 0.5, y + 0.5, c, c, tile / 2, tile / 2, radius)
                if preenchido:
                    a = min(max(stroke / 2 + 0.5 - d, 0), 1)
                else:
                    a = min(max(stroke / 2 + 0.5 - abs(d), 0), 1)
                raw.extend((STROKE[0], STROKE[1], STROKE[2], int(a * 255)))
        def chunk(tag, data):
            cc = tag + data
            return struct.pack(">I", len(data)) + cc + struct.pack(">I", zlib.crc32(cc) & 0xFFFFFFFF)
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
        open(f"{OUT}/ui/{nome}", "wb").write(png)
    print("intro", {"tile": tile, "gap": icon_size * 0.12, "size": size})


render("icon_focus_fhd.png", 540, 405, 250)
render("icon_focus_hd.png", 290, 218, 134)
render("splash_fhd.png", 1920, 1080, 300)
intro_tiles(300)
print("ok")
