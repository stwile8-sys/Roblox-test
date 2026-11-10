#!/usr/bin/env python3
"""Простые иконки 512×512 для геймпассов и товаров (Pillow). Без текста: цветной круг + глиф.

Запуск: python3 tools/assets/make_icons.py  -> tools/assets/icons/<key>.png
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
S = 512
C = S // 2

GOLD = (255, 205, 60)
WHITE = (255, 255, 255)
DARK = (30, 25, 50)


def star(d, cx, cy, r, fill, points=5, inner=0.45):
    pts = []
    for i in range(points * 2):
        a = -math.pi / 2 + i * math.pi / points
        rr = r if i % 2 == 0 else r * inner
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=fill)


def gem(d, cx, cy, r, fill):
    d.polygon([(cx, cy - r), (cx + r * 0.8, cy - r * 0.2), (cx, cy + r), (cx - r * 0.8, cy - r * 0.2)], fill=fill)
    d.polygon([(cx, cy - r), (cx + r * 0.3, cy - r * 0.2), (cx, cy + r), (cx - r * 0.3, cy - r * 0.2)], fill=tuple(min(255, c + 70) for c in fill[:3]))


def bolt(d, cx, cy, r, fill):
    d.polygon([(cx + r * 0.2, cy - r), (cx - r * 0.55, cy + r * 0.1), (cx - r * 0.05, cy + r * 0.1),
               (cx - r * 0.25, cy + r), (cx + r * 0.55, cy - r * 0.15), (cx + r * 0.05, cy - r * 0.15)], fill=fill)


def magnet(d, cx, cy, r, fill):
    w = r * 0.38
    d.arc([cx - r, cy - r, cx + r, cy + r], 0, 180, fill=fill, width=int(w))
    d.rectangle([cx - r, cy - r * 0.6, cx - r + w, cy], fill=fill)
    d.rectangle([cx + r - w, cy - r * 0.6, cx + r, cy], fill=fill)
    d.rectangle([cx - r, cy - r * 0.85, cx - r + w, cy - r * 0.6], fill=WHITE)
    d.rectangle([cx + r - w, cy - r * 0.85, cx + r, cy - r * 0.6], fill=WHITE)


def eye(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r * 0.55, cx + r, cy + r * 0.55], fill=WHITE)
    d.ellipse([cx - r * 0.42, cy - r * 0.42, cx + r * 0.42, cy + r * 0.42], fill=fill)
    d.ellipse([cx - r * 0.18, cy - r * 0.18, cx + r * 0.18, cy + r * 0.18], fill=DARK)


def floors(d, cx, cy, r, fill):
    for i, y in enumerate((cy - r * 0.55, cy + r * 0.25)):
        d.rectangle([cx - r * 0.8, y - r * 0.3, cx + r * 0.8, y + r * 0.3], fill=fill)
        for k in range(-2, 3):
            d.rectangle([cx + k * r * 0.3 - r * 0.08, y - r * 0.12, cx + k * r * 0.3 + r * 0.08, y + r * 0.12], fill=DARK)
    d.polygon([(cx - r, cy - r * 0.85), (cx, cy - r * 1.25), (cx + r, cy - r * 0.85)], fill=fill)


def box(d, cx, cy, r, fill):
    d.rectangle([cx - r * 0.8, cy - r * 0.3, cx + r * 0.8, cy + r * 0.8], fill=fill)
    d.rectangle([cx - r * 0.9, cy - r * 0.6, cx + r * 0.9, cy - r * 0.25], fill=fill)
    d.rectangle([cx - r * 0.12, cy - r * 0.6, cx + r * 0.12, cy + r * 0.8], fill=WHITE)


def crown(d, cx, cy, r, fill):
    d.polygon([(cx - r, cy + r * 0.5), (cx - r, cy - r * 0.5), (cx - r * 0.5, cy), (cx, cy - r * 0.8),
               (cx + r * 0.5, cy), (cx + r, cy - r * 0.5), (cx + r, cy + r * 0.5)], fill=fill)
    for x in (-r, 0, r):
        d.ellipse([cx + x - r * 0.13, cy - r * 0.95 + (0 if x == 0 else r * 0.3) - r * 0.13 + (0 if x == 0 else 0),
                   cx + x + r * 0.13, cy - r * 0.95 + (0 if x == 0 else r * 0.3) + r * 0.13], fill=fill)


def hourglass(d, cx, cy, r, fill):
    d.polygon([(cx - r * 0.7, cy - r), (cx + r * 0.7, cy - r), (cx, cy), (cx + r * 0.7, cy + r), (cx - r * 0.7, cy + r), (cx, cy)], fill=fill)
    d.rectangle([cx - r * 0.85, cy - r * 1.1, cx + r * 0.85, cy - r * 0.92], fill=WHITE)
    d.rectangle([cx - r * 0.85, cy + r * 0.92, cx + r * 0.85, cy + r * 1.1], fill=WHITE)


def x2(d, cx, cy, r, fill):
    # мешок с монетами (парные молнии запрещены — их путают с запрещённым символом)
    d.ellipse([cx - r * 0.75, cy - r * 0.35, cx + r * 0.75, cy + r * 0.95], fill=fill)
    d.polygon([(cx - r * 0.3, cy - r * 0.3), (cx + r * 0.3, cy - r * 0.3), (cx + r * 0.45, cy - r * 0.75), (cx - r * 0.45, cy - r * 0.75)], fill=fill)
    d.rectangle([cx - r * 0.35, cy - r * 0.42, cx + r * 0.35, cy - r * 0.3], fill=(140, 90, 30))
    d.ellipse([cx - r * 0.28, cy + r * 0.05, cx + r * 0.28, cy + r * 0.61], fill=(255, 235, 140))
    d.ellipse([cx - r * 0.17, cy + r * 0.16, cx + r * 0.17, cy + r * 0.5], fill=fill)
    for dx, dy in ((r * 0.75, -r * 0.55), (r * 0.95, -r * 0.1)):
        d.ellipse([cx + dx - r * 0.18, cy + dy - r * 0.18, cx + dx + r * 0.18, cy + dy + r * 0.18], fill=(255, 235, 140))


def blackhole(d, cx, cy, r, fill):
    for i in range(6, 0, -1):
        rr = r * i / 6
        c = tuple(int(fill[k] * (i / 6) + DARK[k] * (1 - i / 6)) for k in range(3))
        d.ellipse([cx - rr, cy - rr * 0.45, cx + rr, cy + rr * 0.45], fill=c)
    d.ellipse([cx - r * 0.35, cy - r * 0.35, cx + r * 0.35, cy + r * 0.35], fill=(0, 0, 0))


ICONS = {
    # key: (цвет круга, глиф, цвет глифа)
    "VIP": ((150, 60, 220), crown, GOLD),
    "AutoCollect": ((40, 170, 110), magnet, (230, 60, 60)),
    "ScannerPlus": ((30, 120, 220), eye, (60, 200, 255)),
    "SecondFloor": ((230, 120, 30), floors, WHITE),
    "Starter": ((60, 180, 230), box, GOLD),
    "Titan": ((60, 40, 110), blackhole, (190, 120, 255)),
    "Shards100": ((70, 90, 200), gem, (120, 230, 255)),
    "Shards550": ((90, 70, 210), gem, (160, 200, 255)),
    "Shards1500": ((120, 50, 220), gem, (220, 170, 255)),
    "Energy5": ((240, 180, 20), bolt, WHITE),
    # BoostX2: раньше были две молнии — модерация приняла их за запрещённый символ. Теперь мешок с монетами. Парные молнии не рисовать!
    "BoostX2": ((40, 170, 110), x2, GOLD),
    "SeasonPass": ((20, 150, 160), hourglass, GOLD),
}


def make(key, bg, glyph, fg):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([16, 16, S - 16, S - 16], fill=tuple(max(0, c - 50) for c in bg))
    d.ellipse([36, 36, S - 36, S - 36], fill=bg)
    hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse([110, 70, S - 180, 190], fill=(255, 255, 255, 45))  # блик
    img = Image.alpha_composite(img, hl)
    d = ImageDraw.Draw(img)
    glyph(d, C, C + 10, 150, fg)
    if key in ("Shards550", "Shards1500"):
        star(d, C + 140, C - 140, 40, GOLD)
    if key == "Shards1500":
        star(d, C - 140, C - 140, 40, GOLD)
    img.save(os.path.join(OUT, key + ".png"), optimize=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for k, (bg, g, fg) in ICONS.items():
        make(k, bg, g, fg)
        print("icon", k)


if __name__ == "__main__":
    main()
