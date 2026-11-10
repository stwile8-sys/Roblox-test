#!/usr/bin/env python3
"""Иконка (512×512) и превью (1920×1080) для страницы игры. Только Pillow, рисуется кодом.

Запуск: python3 tools/promo/make_cover.py  → tools/promo/out/
Варианты иконки: A — кукла летит сквозь кольцо, B — пушка стреляет куклой, C — кукла крупно в небе со следом.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
INK = (43, 35, 80)
FONT = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
SK = 4  # суперсэмплинг для гладких краёв


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def sky(w, h, top=(110, 190, 255), bottom=(200, 236, 255)):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        k = y / h
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] * (1 - k) + bottom[i] * k) for i in range(3)))
    return im


def rot(pts, cx, cy, a):
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]


def box(d, cx, cy, w, h, a, fill, ow):
    pts = rot([(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)], cx, cy, a)
    d.polygon(pts, fill=fill, outline=INK, width=ow)


def cloud(d, x, y, s):
    for dx, dy, r in ((0, 0, 1.0), (0.9, 0.15, 0.75), (-0.85, 0.2, 0.7), (0.3, -0.35, 0.65)):
        rr = r * s
        d.ellipse([x + dx * s - rr, y + dy * s - rr, x + dx * s + rr, y + dy * s + rr], fill=(255, 255, 255))


def ring(d, cx, cy, r, ow, tilt=0.45):
    # золотое кольцо в перспективе: эллипс с толстой обводкой
    rx, ry = r * tilt, r
    d.ellipse([cx - rx - ow, cy - ry - ow, cx + rx + ow, cy + ry + ow], outline=INK, width=int(ow * 2.6))
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=(255, 210, 60), width=int(ow * 1.6))
    d.ellipse([cx - rx + ow * 0.3, cy - ry + ow * 0.3, cx + rx - ow * 0.3, cy + ry - ow * 0.3], outline=(255, 245, 170), width=max(2, int(ow * 0.4)))


def ragdoll(d, cx, cy, s, a, ow, shirt=(255, 107, 61), pants=(60, 90, 200), skin=(255, 214, 90)):
    """Кубическая кукла в «звезде»: руки и ноги раскинуты под разными углами. s — высота торса."""
    t = s
    # ноги
    for side, ang in ((-1, 0.55), (1, -0.35)):
        lx, ly = rot([(side * t * 0.22, t * 0.75)], cx, cy, a)[0]
        box(d, lx, ly, t * 0.38, t * 0.95, a + ang * side, pants, ow)
    # руки
    for side, ang in ((-1, 1.25), (1, 1.6)):
        hx, hy = rot([(side * t * 0.7, -t * 0.32)], cx, cy, a)[0]
        box(d, hx, hy, t * 0.34, t * 0.9, a + ang * side, skin, ow)
    # торс
    box(d, cx, cy, t * 0.95, t, a, shirt, ow)
    # голова
    hx, hy = rot([(0, -t * 0.82)], cx, cy, a)[0]
    box(d, hx, hy, t * 0.62, t * 0.6, a + 0.15, skin, ow)
    # лицо: глаза-точки и открытый рот — «ААА»
    for ex in (-0.13, 0.13):
        px, py = rot([(ex * t, -t * 0.88)], cx, cy, a + 0.15)[0]
        r = t * 0.05
        d.ellipse([px - r, py - r, px + r, py + r], fill=INK)
    mx, my = rot([(0, -t * 0.68)], cx, cy, a + 0.15)[0]
    r = t * 0.08
    d.ellipse([mx - r, my - r * 0.9, mx + r, my + r * 1.2], fill=INK)


def trail(d, pts, width):
    cols = [(120, 220, 255), (255, 214, 70), (255, 107, 61)]
    n = len(pts) - 1
    for i in range(n):
        k = i / n
        c = cols[min(int(k * len(cols)), len(cols) - 1)]
        w = int(width * (0.25 + 0.75 * k))
        d.line([pts[i], pts[i + 1]], fill=c, width=w)


def cannon(d, x, y, s, a, ow):
    # ствол
    box(d, x + math.cos(a) * s * 0.55, y + math.sin(a) * s * 0.55, s * 1.25, s * 0.55, a, (255, 107, 61), ow)
    mx, my = x + math.cos(a) * s * 1.15, y + math.sin(a) * s * 1.15
    box(d, mx, my, s * 0.2, s * 0.68, a, (255, 210, 60), ow)
    # колесо
    r = s * 0.42
    d.ellipse([x - r, y - r + s * 0.25, x + r, y + r + s * 0.25], fill=(110, 80, 150), outline=INK, width=ow)
    return mx, my


def blast(d, x, y, r, ow):
    pts = []
    for i in range(16):
        ang = i / 16 * math.tau
        rr = r * (1.0 if i % 2 == 0 else 0.55)
        pts.append((x + math.cos(ang) * rr, y + math.sin(ang) * rr))
    d.polygon(pts, fill=(255, 230, 120), outline=INK, width=ow)


def text(d, xy, s, size, fill=(255, 255, 255), anchor="mm"):
    d.text(xy, s, font=font(size), fill=fill, anchor=anchor, stroke_width=max(4, size // 9), stroke_fill=INK)


def ground(d, w, h, y0):
    cols = [(108, 196, 92), (246, 222, 150), (232, 182, 104), (236, 246, 255), (255, 176, 214)]
    seg = w / len(cols)
    for i, c in enumerate(cols):
        d.rectangle([i * seg, y0, (i + 1) * seg, h], fill=c)
    d.line([(0, y0), (w, y0)], fill=INK, width=max(4, h // 120))


def finish(im, size):
    return im.resize(size, Image.LANCZOS)


def round_icon(im):
    s = im.size[0]
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.18), fill=255)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def icon_a():
    S = 512 * SK
    im = sky(S, S)
    d = ImageDraw.Draw(im)
    cloud(d, S * 0.2, S * 0.25, S * 0.07)
    cloud(d, S * 0.82, S * 0.78, S * 0.08)
    ow = 8 * SK
    trail(d, [(S * 0.0 + i * S * 0.045, S * 1.0 - i * S * 0.05 - (i * i) * S * 0.0006) for i in range(12)], 60 * SK)
    ring(d, S * 0.6, S * 0.42, S * 0.3, 14 * SK)
    ragdoll(d, S * 0.55, S * 0.46, S * 0.24, -0.6, ow)
    # передняя половина кольца поверх куклы
    rx, ry = S * 0.3 * 0.45, S * 0.3
    cx, cy = S * 0.6, S * 0.42
    d.arc([cx - rx - 14 * SK, cy - ry - 14 * SK, cx + rx + 14 * SK, cy + ry + 14 * SK], -90, 90, fill=INK, width=int(14 * SK * 2.6))
    d.arc([cx - rx, cy - ry, cx + rx, cy + ry], -90, 90, fill=(255, 210, 60), width=int(14 * SK * 1.6))
    return round_icon(finish(im, (512, 512)))


def icon_b():
    S = 512 * SK
    im = sky(S, S, (255, 170, 120), (255, 226, 170))
    d = ImageDraw.Draw(im)
    ground(d, S, S, S * 0.84)
    ow = 8 * SK
    mx, my = cannon(d, S * 0.2, S * 0.74, S * 0.32, -0.8, ow)
    blast(d, mx + S * 0.03, my - S * 0.03, S * 0.13, ow)
    trail(d, [(mx + i * S * 0.04, my - i * S * 0.045) for i in range(9)], 46 * SK)
    ragdoll(d, S * 0.7, S * 0.28, S * 0.22, 0.5, ow)
    return round_icon(finish(im, (512, 512)))


def icon_c():
    S = 512 * SK
    im = sky(S, S, (90, 170, 255), (170, 225, 255))
    d = ImageDraw.Draw(im)
    random.seed(3)
    for _ in range(4):
        cloud(d, random.uniform(0, S), random.uniform(S * 0.6, S), S * random.uniform(0.05, 0.09))
    ow = 9 * SK
    pts = []
    for i in range(14):
        k = i / 13
        pts.append((S * (0.02 + 0.5 * k), S * (0.98 - 0.55 * k + 0.1 * math.sin(k * 6))))
    trail(d, pts, 80 * SK)
    for (x, y, r) in ((0.78, 0.22, 0.09), (0.86, 0.5, 0.07), (0.25, 0.3, 0.06)):
        ring(d, S * x, S * y, S * r, 7 * SK)
    ragdoll(d, S * 0.55, S * 0.42, S * 0.3, -0.35, ow)
    return round_icon(finish(im, (512, 512)))


def thumb(variant):
    W, H = 1920 * 2, 1080 * 2
    im = sky(W, H)
    d = ImageDraw.Draw(im)
    random.seed(variant)
    for _ in range(7):
        cloud(d, random.uniform(0, W), random.uniform(0, H * 0.6), W * random.uniform(0.025, 0.05))
    ground(d, W, H, H * 0.86)
    ow = 12
    mx, my = cannon(d, W * 0.1, H * 0.8, H * 0.22, -0.75, ow)
    blast(d, mx + 20, my - 20, H * 0.08, ow)
    tx, ty = (W * 0.66, H * 0.3) if variant == 1 else (W * 0.58, H * 0.34)
    cxp, cyp = (mx + tx) / 2, min(my, ty) - H * 0.25
    pts = []
    for i in range(22):
        k = i / 21
        pts.append(((1 - k) ** 2 * mx + 2 * (1 - k) * k * cxp + k * k * tx, (1 - k) ** 2 * my + 2 * (1 - k) * k * cyp + k * k * ty))
    trail(d, pts, 90)
    for (x, y, r) in ((0.47, 0.42, 0.11), (0.8, 0.3, 0.1), (0.9, 0.5, 0.07)):
        ring(d, W * x, H * y, H * r, 14)
    if variant == 1:
        ragdoll(d, W * 0.66, H * 0.32, H * 0.16, -0.5, ow)
        text(d, (W * 0.5, H * 0.08), "LAUNCH YOURSELF!", 200)
        text(d, (W * 0.83, H * 0.72), "+1 POWER", 150, (120, 220, 255))
        text(d, (W * 0.83, H * 0.8), "EVERY SECOND", 90, (255, 255, 255))
    else:
        for i, (x, y, a, c) in enumerate(((0.58, 0.34, -0.4, (255, 107, 61)), (0.7, 0.4, 0.6, (60, 196, 106)), (0.45, 0.45, 1.2, (176, 120, 255)))):
            ragdoll(d, W * x, H * y, H * 0.12, a, ow, shirt=c)
        text(d, (W * 0.5, H * 0.08), "FLY WITH FRIENDS!", 200)
        text(d, (W * 0.83, H * 0.76), "30,000m", 170, (255, 214, 70))
    return finish(im, (1920, 1080))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("icon_A", icon_a), ("icon_B", icon_b), ("icon_C", icon_c)):
        fn().save(os.path.join(OUT, name + ".png"))
    thumb(1).save(os.path.join(OUT, "thumb_1.png"))
    thumb(2).save(os.path.join(OUT, "thumb_2.png"))
    # лист проверки: каждая иконка крупно и в 100×100
    sheet = Image.new("RGBA", (3 * 300, 420), (245, 245, 245, 255))
    for i, n in enumerate(("icon_A", "icon_B", "icon_C")):
        ic = Image.open(os.path.join(OUT, n + ".png"))
        sheet.paste(ic.resize((280, 280)), (i * 300 + 10, 10), ic.resize((280, 280)))
        sm = ic.resize((100, 100), Image.LANCZOS)
        sheet.paste(sm, (i * 300 + 100, 305), sm)
    sheet.save(os.path.join(OUT, "check_sheet.png"))
    print("ok")
