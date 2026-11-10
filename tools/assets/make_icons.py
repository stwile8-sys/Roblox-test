#!/usr/bin/env python3
"""Иконки геймпассов и товаров «+1 Launch Power» (512×512 PNG). Только Pillow.

Запуск: python3 tools/assets/make_icons.py  → tools/assets/icons/<id>.png
Стиль: яркий фон, толстая тёмная обводка, крупный белый текст с обводкой, простой значок.
Никаких рун и молний парой (у аккаунта было предупреждение) — молния одна.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
INK = (43, 35, 80)
FONT_PATHS = [
    "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]
S = 512


def font(size):
    for p in FONT_PATHS:
        if os.path.isfile(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def base(bg, bg2):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # лёгкий вертикальный перелив фона
    for y in range(S):
        k = y / S
        c = tuple(int(bg[i] * (1 - k) + bg2[i] * k) for i in range(3))
        d.line([(0, y), (S, y)], fill=c + (255,))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=110, fill=255)
    im.putalpha(mask)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([10, 10, S - 11, S - 11], radius=104, outline=INK, width=20)
    return im, d


def text(d, xy, s, size, fill=(255, 255, 255)):
    f = font(size)
    d.text(xy, s, font=f, fill=fill, anchor="mm", stroke_width=max(6, size // 10), stroke_fill=INK)


def bolt(d, cx, cy, k=1.0, fill=(255, 214, 70)):
    pts = [(-30, -120), (55, -120), (15, -25), (70, -25), (-40, 125), (-10, 15), (-60, 15)]
    pts = [(cx + x * k, cy + y * k) for x, y in pts]
    d.polygon(pts, fill=fill, outline=INK, width=int(12 * k))


def coin(d, cx, cy, r):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 201, 60), outline=INK, width=14)
    d.ellipse([cx - r * 0.62, cy - r * 0.62, cx + r * 0.62, cy + r * 0.62], outline=(214, 150, 0), width=10)


def rocket(d, cx, cy, k=1.0):
    body = [(0, -150), (55, -60), (55, 70), (-55, 70), (-55, -60)]
    d.polygon([(cx + x * k, cy + y * k) for x, y in body], fill=(255, 255, 255), outline=INK, width=int(12 * k))
    for sx in (-1, 1):
        fin = [(55 * sx, 10), (100 * sx, 90), (55 * sx, 70)]
        d.polygon([(cx + x * k, cy + y * k) for x, y in fin], fill=(255, 107, 61), outline=INK, width=int(10 * k))
    d.ellipse([cx - 26 * k, cy - 60 * k, cx + 26 * k, cy - 8 * k], fill=(120, 220, 255), outline=INK, width=int(10 * k))
    flame = [(-35, 70), (35, 70), (0, 150)]
    d.polygon([(cx + x * k, cy + y * k) for x, y in flame], fill=(255, 201, 60), outline=INK, width=int(10 * k))


def crown(d, cx, cy):
    pts = [(-150, 70), (-150, -60), (-75, 0), (0, -100), (75, 0), (150, -60), (150, 70)]
    d.polygon([(cx + x, cy + y) for x, y in pts], fill=(255, 214, 70), outline=INK, width=16)


def make(key):
    if key == "VIP":
        im, d = base((176, 120, 255), (120, 80, 220))
        crown(d, 256, 200)
        text(d, (256, 380), "VIP", 150)
    elif key == "Power2x":
        im, d = base((90, 200, 255), (40, 140, 230))
        bolt(d, 170, 250, 1.3)
        text(d, (340, 260), "2x", 170)
    elif key == "Coins2x":
        im, d = base((255, 214, 90), (255, 160, 40))
        coin(d, 165, 255, 105)
        text(d, (345, 260), "2x", 170)
    elif key == "AutoLaunch":
        im, d = base((60, 196, 106), (30, 150, 80))
        rocket(d, 256, 205, 1.0)
        text(d, (256, 410), "AUTO", 110)
    elif key in ("PowerS", "PowerM", "PowerL"):
        n = {"PowerS": 1, "PowerM": 2, "PowerL": 3}[key]
        im, d = base((90, 200, 255), (40, 140, 230))
        coin_bg = [(None), (255, 255, 255), (255, 240, 170), (255, 214, 70)][n]
        d.ellipse([256 - 120, 215 - 120, 256 + 120, 215 + 120], fill=coin_bg, outline=INK, width=14)
        bolt(d, 256, 215, 0.75 + 0.1 * n)
        text(d, (256, 410), {1: "+10 MIN", 2: "+45 MIN", 3: "+3 HRS"}[n], 84)
    elif key == "Boost15":
        im, d = base((255, 107, 61), (230, 70, 40))
        bolt(d, 256, 200, 1.2)
        text(d, (256, 400), "2x 15m", 100)
    elif key == "Coins":
        im, d = base((255, 214, 90), (255, 160, 40))
        for x, y, r in ((190, 250, 90), (320, 230, 90), (255, 160, 80)):
            coin(d, x, y, r)
        text(d, (256, 410), "COINS", 110)
    elif key == "LaunchAll":
        im, d = base((255, 107, 61), (200, 60, 120))
        for i, off in enumerate((-120, 0, 120)):
            rocket(d, 256 + off, 210 - (40 if i == 1 else 0), 0.62)
        text(d, (256, 410), "EVERYONE", 82)
    else:
        raise KeyError(key)
    return im


KEYS = ["VIP", "Power2x", "Coins2x", "AutoLaunch", "PowerS", "PowerM", "PowerL", "Boost15", "Coins", "LaunchAll"]

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for k in KEYS:
        make(k).save(os.path.join(OUT, k + ".png"))
        print("ok", k)
