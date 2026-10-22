"""Gera as imagens dos mascotes do Meu Menu.

- Pikachu correndo: GIF estilo anime (gifdb.com/gif/pokemon-pikachu-running-fdcgna00aeogxcjz.html),
  salvo em tools/sprites_fonte/pikachu_correndo.gif. O fundo branco e removido por
  preenchimento a partir das bordas (o branco de dentro do desenho fica intacto).
- Rimuru slime pulando: desenhado aqui. Um pulo completo em 16 quadros (agacha, estica no
  impulso, sobe em arco, amassa no pouso), com sombra no chao que encolhe no ar.
- Olhos do Gengar: desenhados aqui (vetor com brilho).

As imagens saem no tamanho exato de pixels da TV 720p. Requer Pillow.
Uso: python3 gerar_mascotes.py
"""
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps, ImageSequence

TOOLS = Path(__file__).resolve().parent
FONTE = TOOLS / "sprites_fonte"
DESTINO = TOOLS.parent / "app" / "images" / "mascotes"


def limpar(padrao):
    for antigo in DESTINO.glob(padrao):
        antigo.unlink()


# ---------- Pikachu ----------

def sem_fundo_branco(quadro):
    """Torna transparente o branco ligado as bordas e suaviza a borda do recorte."""
    rgb = quadro.convert("RGB")
    marcado = rgb.copy()
    w, h = rgb.size
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (w // 2, h - 1)):
        if marcado.getpixel((x, y)) != (255, 0, 255):
            ImageDraw.floodfill(marcado, (x, y), (255, 0, 255), thresh=48)
    fundo = Image.eval(ImageChops.difference(marcado, Image.new("RGB", (w, h), (255, 0, 255))).convert("L"),
                       lambda v: 255 if v < 8 else 0)
    alfa = ImageChops.invert(fundo).filter(ImageFilter.GaussianBlur(0.7))
    resultado = rgb.convert("RGBA")
    resultado.putalpha(alfa)
    return resultado


def gerar_pikachu(altura=30):
    gif = Image.open(FONTE / "pikachu_correndo.gif")
    quadros = [sem_fundo_branco(q) for q in ImageSequence.Iterator(gif)]
    duracao = gif.info.get("duration", 80)

    # Recorte comum a todos os quadros (mantem o movimento natural dentro do ciclo)
    caixa = None
    for q in quadros:
        b = q.getbbox()
        caixa = b if caixa is None else (min(caixa[0], b[0]), min(caixa[1], b[1]), max(caixa[2], b[2]), max(caixa[3], b[3]))
    largura = round((caixa[2] - caixa[0]) * altura / (caixa[3] - caixa[1]))

    limpar("pato_*.png")
    limpar("pikachu_*.png")
    for i, q in enumerate(quadros):
        quadro = q.crop(caixa).resize((largura, altura), Image.LANCZOS)
        quadro.save(DESTINO / f"pikachu_{i:02d}.png", optimize=True)
        ImageOps.mirror(quadro).save(DESTINO / f"pikachu_m{i:02d}.png", optimize=True)
    print("pikachu", {"frameWidth": largura, "frameHeight": altura, "frames": len(quadros), "fps": round(1000 / duracao, 1)})


def bezier(p0, p1, p2, n=24):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
            for t in (i / n for i in range(n + 1))]


SLIME_CONTORNO = (52, 128, 196, 255)
SLIME_CORPO = (110, 190, 240, 255)
SLIME_CLARO = (170, 225, 252, 255)
SLIME_OLHO = (30, 50, 90, 255)


def forma_slime(cx, base, r, sx, sy):
    """Gota com a pontinha do Rimuru, apoiada em (cx, base), deformada por sx/sy."""
    def p(x, y):
        return (cx + x * r * sx, base + y * r * sy)
    # Lados bem arredondados subindo ate uma pontinha curta, levemente torta
    esquerda = bezier(p(-1.05, 0), p(-1.22, -0.62), p(-0.55, -0.98))
    ombro_e = bezier(p(-0.55, -0.98), p(-0.18, -1.16), p(0.06, -1.34))
    ombro_d = bezier(p(0.06, -1.34), p(0.16, -1.12), p(0.55, -0.98))
    direita = bezier(p(0.55, -0.98), p(1.22, -0.64), p(1.05, 0))
    baixo = bezier(p(1.05, 0), p(0, 0.16), p(-1.05, 0))
    return esquerda + ombro_e[1:] + ombro_d[1:] + direita[1:] + baixo[1:]


def quadro_slime(sx, sy, altura_pulo, s):
    W, H = 80 * s, 96 * s
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    chao = 90 * s
    r = 26 * s
    cx = W / 2

    # Sombra no chao: menor e mais clara quanto mais alto
    alto = altura_pulo / (34 * s)
    sombra = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rs = r * (1.05 - 0.45 * alto) * sx
    ImageDraw.Draw(sombra).ellipse((cx - rs, chao - 4 * s, cx + rs, chao + 4 * s), fill=(0, 0, 0, int(110 * (1 - 0.6 * alto))))
    img = Image.alpha_composite(img, sombra.filter(ImageFilter.GaussianBlur(2 * s)))
    d = ImageDraw.Draw(img)

    base = chao - altura_pulo
    d.polygon(forma_slime(cx, base + 1.5 * s, r + 2 * s, sx, sy), fill=SLIME_CONTORNO)
    d.polygon(forma_slime(cx, base, r, sx, sy), fill=SLIME_CORPO)
    # Volume: parte de cima mais clara
    d.polygon(forma_slime(cx - 2 * s * sx, base - 8 * s * sy, r * 0.72, sx, sy), fill=SLIME_CLARO)
    # Brilho
    hx, hy = cx - 11 * s * sx, base - 26 * s * sy
    d.ellipse((hx - 5 * s * sx, hy - 3 * s * sy, hx + 5 * s * sx, hy + 3 * s * sy), fill=(255, 255, 255, 230))
    # Olhinhos fechados felizes (arquinhos para cima)
    oy = base - 13 * s * sy
    for lado in (-1, 1):
        ox = cx + lado * 9 * s * sx
        d.arc((ox - 5 * s * sx, oy - 3 * s * sy, ox + 5 * s * sx, oy + 5 * s * sy), start=200, end=340, fill=SLIME_OLHO, width=max(1, int(2.4 * s)))
    return img


def gerar_rimuru(altura=56):
    """Um pulo em 16 quadros: agacha (0-3), impulso e arco no ar (4-10), pouso amassado (11-15)."""
    s = 4
    poses = [  # (escala x, escala y, altura do pulo em px)
        (1.00, 1.00, 0), (1.08, 0.90, 0), (1.18, 0.78, 0), (1.22, 0.74, 0),
        (0.86, 1.22, 6), (0.90, 1.14, 18), (0.96, 1.05, 28), (1.00, 1.00, 33),
        (1.00, 1.00, 33), (0.97, 1.04, 27), (0.92, 1.12, 15),
        (1.26, 0.70, 0), (1.14, 0.84, 0), (0.96, 1.06, 0), (1.02, 0.98, 0), (1.00, 1.00, 0),
    ]
    limpar("rimuru_*.png")
    largura = round(80 * altura / 96)
    for i, (sx, sy, h) in enumerate(poses):
        quadro_slime(sx, sy, h * s, s).resize((largura, altura), Image.LANCZOS).save(DESTINO / f"rimuru_{i:02d}.png", optimize=True)
    print("rimuru", {"frameWidth": largura, "frameHeight": altura, "frames": len(poses)})


# ---------- Olhos do Gengar ----------

def olho(s):
    """Olho esquerdo (do observador) em forma de amendoa: cantos arredondados, borda de cima
    com leve arco descendo para o centro (cara de bravo) e borda de baixo bem curva."""
    externo, interno = (30 * s, 22 * s), (114 * s, 60 * s)
    topo = bezier(externo, (70 * s, 26 * s), interno)
    base = bezier(interno, (94 * s, 92 * s), (44 * s, 62 * s))
    canto = bezier((44 * s, 62 * s), (22 * s, 44 * s), externo)
    return topo + base[1:] + canto[1:]


def contorno(forma, cx, cy, fator):
    return [(cx + (x - cx) * fator, cy + (y - cy) * fator) for x, y in forma]


def gerar_olhos(largura=260, altura=110, margem=30):
    s = 4  # supersampling
    W, H = (largura + 2 * margem) * s, (altura + 2 * margem) * s
    off = margem * s
    esquerdo = [(x + off, y + off) for x, y in olho(s)]
    direito = [(W - x, y) for x, y in esquerdo]

    # Brilho vermelho em volta
    brilho = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(brilho)
    for forma in (esquerdo, direito):
        d.polygon(forma, fill=(255, 40, 70, 200))
    brilho = brilho.filter(ImageFilter.GaussianBlur(14 * s))

    # Olhos: contorno vinho por baixo, vermelho rosado por cima, centro mais claro
    olhos = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(olhos)
    for forma in (esquerdo, direito):
        cx = sum(p[0] for p in forma) / len(forma)
        cy = sum(p[1] for p in forma) / len(forma)
        d.polygon(contorno(forma, cx, cy, 1.08), fill=(90, 0, 20, 255))
        d.polygon(forma, fill=(214, 24, 58, 255))
    centro = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dc = ImageDraw.Draw(centro)
    for forma in (esquerdo, direito):
        xs = [p[0] for p in forma]
        ys = [p[1] for p in forma]
        cx, cy = sum(xs) / len(xs), sum(ys) / len(ys) + 4 * s
        dc.ellipse((cx - 30 * s, cy - 14 * s, cx + 30 * s, cy + 14 * s), fill=(255, 120, 130, 255))
    centro = centro.filter(ImageFilter.GaussianBlur(9 * s))
    mascara = olhos.split()[3]
    olhos = Image.alpha_composite(olhos, Image.composite(centro, Image.new("RGBA", (W, H)), mascara))

    # Pupilas pequenas perto do centro do rosto
    d = ImageDraw.Draw(olhos)
    for px in (88 * s + off, W - 88 * s - off):
        py = 62 * s + off
        d.ellipse((px - 6 * s, py - 8 * s, px + 6 * s, py + 8 * s), fill=(70, 0, 14, 255))

    escala = 2 / 3  # olhos reduzidos em 1/3
    final = Image.alpha_composite(brilho, olhos).resize((round(W / s * escala), round(H / s * escala)), Image.LANCZOS)
    final.save(DESTINO / "gengar_olhos.png", optimize=True)
    print("olhos", final.size)


DESTINO.mkdir(parents=True, exist_ok=True)
gerar_pikachu()
gerar_rimuru()
gerar_olhos()
