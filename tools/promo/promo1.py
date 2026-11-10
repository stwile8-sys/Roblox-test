#!/usr/bin/env python3
"""Промо-ролик №1 «Укради. Защити. Разбогатей.» — вертикаль 1080×1920, 30 к/с, ~21,5 с.

Запуск:  python3 tools/promo/promo1.py ru|en [stills]
  stills — только контрольные кадры в tools/promo/out/stills_<lang>/ (быстро, для проверки перед рендером).
Всё собрано из наших 3D-моделей (tools/models) программным рендером + Pillow; звук синтезируется здесь же.
Нужны: numpy, Pillow, ffmpeg. Чужих картинок, логотипов и музыки нет.
"""
import math
import os
import pickle
import re
import subprocess
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
sys.path.insert(0, os.path.join(ROOT, "tools", "models"))

import artlib as A  # noqa: E402
import make_art as MA  # noqa: E402

W, H, FPS = 1080, 1920, 30
OUT = os.path.join(HERE, "out")
CACHE = os.path.join(OUT, "cache")
os.makedirs(CACHE, exist_ok=True)

LANG = sys.argv[1] if len(sys.argv) > 1 else "ru"
RU = LANG == "ru"

RAR = [  # id, цвет редкости, название редкости
    ("c_drop", "#B8C4D6", "ОБЫЧНЫЙ", "COMMON"),
    ("r_fox", "#4FA8FF", "РЕДКИЙ", "RARE"),
    ("e_dragon", "#B45CFF", "ЭПИЧЕСКИЙ", "EPIC"),
    ("l_owlking", "#FFB347", "ЛЕГЕНДАРНЫЙ", "LEGENDARY"),
    ("x_zero", "#00E5FF", "ХРОНО", "CHRONO"),
]


def names():
    """Имена существ из Defs.luau основной ветки (если файла нет рядом — запасные)."""
    out = {"c_drop": ("Капля Времени", "Time Drop"), "r_fox": ("Кристальный Лис", "Crystal Fox"), "e_dragon": ("Механический Дракончик", "Clockwork Dragon"),
           "l_owlking": ("Совиный Король", "Owl King"), "x_zero": ("Ноль", "Zero")}
    p = os.path.join(ROOT, "src", "shared", "Art", "Defs.luau")
    if os.path.exists(p):
        for m in re.finditer(r'id = "(\w+)".*?ru = "([^"]+)", en = "([^"]+)"', open(p, encoding="utf-8").read()):
            if m.group(1) in out:
                out[m.group(1)] = (m.group(2), m.group(3))
    return out


NAMES = names()


# ---------- кэш спрайтов ----------
def cached(key, fn):
    p = os.path.join(CACHE, re.sub(r"[^\w.-]", "_", key) + ".png")
    if os.path.exists(p):
        return Image.open(p).convert("RGBA")
    im = fn()
    im.save(p)
    return im


def spr(name, px, yaw=-28, pitch=12, **kw):
    return cached(f"{name}_{px}_{yaw}_{pitch}", lambda: A.shot(A.model(name), px, yaw=yaw, pitch=pitch, **kw))


def crop(im):
    b = im.getbbox()
    return im.crop(b) if b else im


def text_spr(s, size, max_w, **kw):
    def make():
        c = Image.new("RGBA", (max_w + 200, int(size * 2.6)), (0, 0, 0, 0))
        A.text(c, s, c.width // 2, c.height // 2, size, max_w=max_w, **kw)
        return crop(c)
    return cached(f"t_{s}_{size}_{max_w}_{kw.get('top','')}_{kw.get('bottom','')}", make)


def ribbon_spr(s, size, max_w, fill="#7B2FF7", fg=(255, 255, 255, 255)):
    def make():
        c = Image.new("RGBA", (max_w + 200, int(size * 3.2)), (0, 0, 0, 0))
        A.ribbon(c, s, c.width // 2, c.height // 2, size, max_w=max_w, fill=fill, fg=fg)
        return crop(c)
    return cached(f"r_{s}_{size}_{max_w}_{fill}_{fg[0]}", make)


_shadow = None


def paste(canvas, sprite, cx, cy, scale=1.0, rot=0.0, anchor="center", alpha=1.0, shadow=False):
    """Быстрая вставка спрайта с масштабом/поворотом/прозрачностью. anchor: center | bottom."""
    global _shadow
    if scale <= 0.01 or alpha <= 0.01:
        return
    if scale != 1.0:
        sprite = sprite.resize((max(1, int(sprite.width * scale)), max(1, int(sprite.height * scale))), Image.BILINEAR)
    if rot:
        sprite = sprite.rotate(rot, expand=True, resample=Image.BICUBIC)
    if alpha < 1:
        sprite = sprite.copy()
        sprite.putalpha(sprite.getchannel("A").point(lambda v: int(v * alpha)))
    x = int(cx - sprite.width / 2)
    y = int(cy - (sprite.height if anchor == "bottom" else sprite.height / 2))
    if shadow:
        if _shadow is None:
            s = Image.new("RGBA", (400, 110), (0, 0, 0, 0))
            ImageDraw.Draw(s).ellipse([40, 25, 360, 85], fill=(42, 33, 64, 110))
            _shadow = s.filter(ImageFilter.GaussianBlur(12))
        sw = max(8, int(sprite.width * 0.9))
        sh = _shadow.resize((sw, max(4, int(sw * 0.27))), Image.BILINEAR)
        by = y + sprite.height * (0.95 if anchor == "bottom" else 1.0)
        _blit(canvas, sh, int(cx - sw / 2), int(by - sh.height / 2))
    _blit(canvas, sprite, x, y)


def _blit(canvas, sprite, x, y):
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(canvas.width, x + sprite.width), min(canvas.height, y + sprite.height)
    if x1 <= x0 or y1 <= y0:
        return
    canvas.alpha_composite(sprite.crop((x0 - x, y0 - y, x1 - x, y1 - y)), (x0, y0))


# ---------- движение ----------
def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def ease(t):
    t = clamp(t)
    return 1 - (1 - t) ** 3


def spring(t, dur=0.45):
    """0→1 с лёгким перелётом."""
    if t <= 0:
        return 0.0
    x = t / dur
    return 1 - math.exp(-5.5 * x) * math.cos(9.0 * x)


def flash(canvas, f, color=(255, 255, 255), n=6):
    if f < n:
        a = int(235 * (1 - f / n) ** 2)
        canvas.alpha_composite(Image.new("RGBA", canvas.size, color + (a,)))


def sky(stops, sun, ray_color=(255, 255, 255), ray_alpha=34, n=16):
    base = A.gradient(W, H, stops)
    base.alpha_composite(A.radial(W, H, sun, H * 0.6, "#FFFFFF", 0.3))
    S = int(math.hypot(W, H) * 1.3)
    rays = A.rays(S, S, (S // 2, S // 2), n, color=ray_color, alpha=ray_alpha)

    def bg(t):
        c = base.copy()
        r = rays.rotate(t * 9, resample=Image.BILINEAR)
        _blit(c, r, int(sun[0] - S / 2), int(sun[1] - S / 2))
        return c
    return bg


def ground(canvas, y=1400, col=((125, 216, 122), (168, 238, 140))):
    d = ImageDraw.Draw(canvas)
    d.ellipse([-500, y, W + 500, y + 1300], fill=col[0] + (255,), outline=A.DARK + (255,), width=8)
    d.ellipse([-420, y + 34, W + 420, y + 1300], fill=col[1] + (255,))


def sparkles(canvas, pts, t):
    for i, (x, y, s) in enumerate(pts):
        k = 0.55 + 0.45 * math.sin(t * 5 + i * 1.7)
        A.sparkle(canvas, x, y, s * k)


# ---------- сцены: каждая возвращает (длительность в секундах, функция кадра f → Image) ----------
def scene_hook():
    bg = sky([(0, "#5B3BFF"), (0.45, "#B56BFF"), (0.75, "#FF9EC4"), (1, "#FFE066")], (540, 1050), ray_alpha=32)
    thief = cached("thief_owl", lambda: A.shot(A.T(A.join(MA.figure("violet", "thief"), A.T(A.model("art_l_owlking"), s=0.62, pos=(0, 6.5, -0.2))), rx=-12), 1000, yaw=40, pitch=6))
    defender = cached("defender", lambda: A.shot(A.T(A.join(MA.figure("orange", "defender"), A.T(A.model("club"), s=0.9, rx=-35, pos=(1.6, 5.6, -0.4))), rx=-10), 520, yaw=58, pitch=6))
    wall = spr("wall3", 900, yaw=-18, pitch=8)
    gate = spr("gate3", 900, yaw=-18, pitch=8)
    t1 = text_spr("УКРАДИ" if RU else "STEAL", 250, 900)
    t2 = text_spr("САМОГО РЕДКОГО!" if RU else "THE RAREST ONE!", 150, 860, top="#FFFFFF", bottom="#7DF3FF")
    coin = [cached(f"coin{i}", lambda i=i: A.shot(A.T(MA.coin(), rx=-62 + 30 * i, rz=20 * i), 70, yaw=40 * i, outline=0.05)) for i in range(4)]

    def frame(f):
        t = f / FPS
        c = bg(t)
        ground(c, 1380)
        paste(c, wall, 140, 1470, anchor="bottom")
        paste(c, gate, 880, 1420, anchor="bottom")
        run = ease(t / 1.3)
        tx = -420 + 1010 * run + 14 * math.sin(t * 3)
        bob = abs(math.sin(t * 11)) * 26
        # защитник догоняет, но отстаёт
        dx = -700 + 900 * ease((t - 0.35) / 1.5) + 10 * math.sin(t * 3 + 1)
        paste(c, defender, dx, 1640 - abs(math.sin(t * 12 + 1)) * 22, rot=4 * math.sin(t * 12), anchor="bottom", shadow=True)
        # линии скорости за вором
        d = ImageDraw.Draw(c)
        for i in range(6):
            ph = (t * 2.2 + i * 0.37) % 1
            ln = 90 + 60 * ((i * 53) % 5)
            x = tx - 250 - ph * 380
            y = 900 + i * 110
            d.rounded_rectangle([x - ln, y - 7, x, y + 7], 7, fill=(255, 255, 255, int(210 * (1 - ph))))
        paste(c, thief, tx, 1740 - bob, rot=3 * math.sin(t * 11), anchor="bottom", shadow=True)
        for i in range(7):  # монеты сыплются из-под ног
            ph = (t * 1.3 + i * 0.29) % 1
            paste(c, coin[i % 4], tx - 120 - ph * 420 - i * 12, 1690 - 240 * math.sin(ph * math.pi) + (i % 3) * 22, rot=ph * 400, alpha=1 - ph ** 3)
        sparkles(c, [(790, 640, 30), (300, 760, 20), (930, 900, 18), (170, 560, 16)], t)
        paste(c, t1, 540, 330, scale=spring(t - 0.1), rot=-3)
        paste(c, t2, 540, 520, scale=spring(t - 0.55), rot=-3)
        flash(c, f)
        return c
    return 3.5, frame


def scene_collection():
    base = A.gradient(W, H, [(0, "#3A1E9C"), (0.5, "#7B2FF7"), (1, "#FF7BB5")])
    base.alpha_composite(A.radial(W, H, (540, 1000), 1100, "#00E5FF", 0.5))
    S = 2700
    rays = A.rays(S, S, (S // 2, S // 2), 20, alpha=24)
    title = text_spr("40 СУЩЕСТВ" if RU else "40 CREATURES", 190, 940)
    sub = ribbon_spr("5 РЕДКОСТЕЙ" if RU else "5 RARITIES", 70, 700)
    yaws = [-34, -24, -14, -4, 6, 16, 26, 36]
    cre, labels, nms, halos = [], [], [], []
    for cid, col, ru, en in RAR:
        cre.append([spr("art_" + cid, 760, yaw=y, pitch=10) for y in yaws])
        dark_fg = col in ("#B8C4D6", "#FFB347", "#00E5FF")
        labels.append(ribbon_spr(ru if RU else en, 84, 900, fill=col, fg=(42, 33, 64, 255) if dark_fg else (255, 255, 255, 255)))
        nms.append(text_spr(NAMES[cid][0 if RU else 1], 84, 940, top="#FFFFFF", bottom="#E8DCFF"))
        halos.append(A.radial(1100, 1100, (550, 550), 540, col, 0.0))
    # маленькие силуэты остальных существ — лента внизу (показывает масштаб коллекции)
    import creatures
    others = [d["id"] for d in creatures.load_defs() if not d["id"].startswith("s")]
    strip = [spr("art_" + i, 150, yaw=-20, pitch=10) for i in others]

    def frame(f):
        t = f / FPS
        c = base.copy()
        _blit(c, rays.rotate(t * 7, resample=Image.BILINEAR), 540 - S // 2, 1000 - S // 2)
        paste(c, title, 540, 310, scale=spring(t - 0.05))
        paste(c, sub, 540, 455, scale=spring(t - 0.3))
        k = int(clamp((t - 0.5), 0, 4.999))  # какое существо на экране (по 1 с)
        lt = t - 0.5 - k
        if t >= 0.5:
            paste(c, halos[k], 540, 1010, scale=0.9 + 0.1 * math.sin(t * 4), alpha=clamp(lt * 5))
            yi = int(clamp(0.5 + 0.5 * math.sin((lt - 0.15) * 3.4)) * (len(yaws) - 1) + 0.5)
            s = cre[k][yi]
            fit = min(760 / s.width, 700 / s.height)
            out = clamp((lt - 0.9) * 10)  # уход в конце секунды
            paste(c, s, 540 - 900 * out ** 2, 1300 - 26 * abs(math.sin(lt * 6.3)), scale=fit * spring(lt, 0.4) * (1 - 0.3 * out), anchor="bottom", shadow=True)
            paste(c, labels[k], 540, 1420, scale=spring(lt - 0.08, 0.35), alpha=1 - out)
            paste(c, nms[k], 540, 1545, scale=spring(lt - 0.16, 0.35), alpha=1 - out)
            if lt < 0.2:
                col = tuple(int(v * 255) for v in A.hexc(RAR[k][1]))
                c.alpha_composite(Image.new("RGBA", c.size, col + (int(150 * (1 - lt / 0.2) ** 2),)))
        # бегущая лента существ внизу
        step = 170
        off = (t * 150) % (step * len(strip))
        for i, s in enumerate(strip):
            x = (i * step - off) % (step * len(strip)) - 100
            if -120 < x < W + 120:
                paste(c, s, x, 1790 + 8 * math.sin(t * 4 + i), anchor="bottom", scale=0.9)
        sparkles(c, [(120, 620, 22), (960, 700, 20), (200, 1250, 16), (930, 1200, 18)], t)
        flash(c, f)
        return c
    return 5.5, frame


def scene_defend():
    bg = sky([(0, "#1E9BFF"), (0.5, "#7FDBFF"), (0.8, "#D9F8FF"), (1, "#FFF1C9")], (540, 980), ray_alpha=30)
    walls = [spr(f"wall{i}", 900, yaw=-20, pitch=12) for i in range(1, 6)]
    lv = [ribbon_spr((f"СТЕНА • УР. {i}" if RU else f"WALL • LV. {i}"), 80, 800, fill="#2C3E50") for i in range(1, 6)]
    title = text_spr("ЗАЩИТИ БАЗУ" if RU else "DEFEND YOUR BASE", 180, 960)
    mine = spr("mine", 260, yaw=-20, pitch=16)
    lock = cached("lockred", lambda: A.shot(A.model("lockButton"), 330, yaw=-20, pitch=20, tint={"Button": "#FF2E63"}))
    defender = cached("defender_big", lambda: A.shot(A.T(A.join(MA.figure("orange", "defender"), A.T(A.model("club"), s=0.9, rx=-35, pos=(1.6, 5.6, -0.4))), rx=-6), 640, yaw=30, pitch=6))
    tags = [ribbon_spr(s, 54, 520, fill="#FF2E63") for s in (("ЛОВУШКИ", "ЗАМОК", "ДУБИНКА") if RU else ("TRAPS", "LOCK", "BAT"))]

    def frame(f):
        t = f / FPS
        c = bg(t)
        for x, y, s in ((170, 700, 60), (900, 620, 70)):
            A.cloud(c, x + 20 * math.sin(t * 0.7 + x), y, s)
        ground(c, 1330)
        paste(c, title, 540, 340, scale=spring(t - 0.05))
        k = int(clamp((t - 0.3) / 0.5, 0, 4))  # уровень стены, шаг 0,5 с
        lt = t - 0.3 - k * 0.5
        w = walls[k]
        fit = min(940 / w.width, 620 / w.height)
        sq = 1 + 0.16 * math.exp(-lt * 9) * math.cos(lt * 22) if t > 0.3 else 1
        w2 = w.resize((int(w.width * fit * (2 - sq)), int(w.height * fit * sq)), Image.BILINEAR)
        paste(c, w2, 540, 1460, anchor="bottom", shadow=True)
        paste(c, lv[k], 540, 560, scale=spring(lt, 0.3) if t > 0.3 else 0)
        # защита: мина, замок, защитник — по очереди
        for i, (sp, x, y, t0) in enumerate(((mine, 200, 1660, 2.6), (lock, 870, 1680, 3.0), (defender, 540, 1790, 3.4))):
            s = spring(t - t0, 0.4)
            rot = 12 * math.sin((t - t0) * 9) * math.exp(-(t - t0) * 2) if (i == 2 and t > t0) else 0
            paste(c, sp, x, y, scale=s, rot=rot, anchor="bottom", shadow=True)
            ty = (1330, 1330, 1050)[i]
            tx = (210, 860, 540)[i]
            if i < 2:
                paste(c, tags[i], tx, ty + 60, scale=spring(t - t0 - 0.1, 0.3))
        flash(c, f)
        return c
    return 4.5, frame


def scene_rich():
    bg = sky([(0, "#FF8A3D"), (0.45, "#FFB347"), (0.8, "#FFE066"), (1, "#FFF6C9")], (540, 1150), ray_color=(255, 255, 255), ray_alpha=46, n=18)
    chest = cached("chest_open", lambda: A.shot(MA.chest_open(64), 900, yaw=-22, pitch=18))
    coin = [cached(f"coinb{i}", lambda i=i: A.shot(A.T(MA.coin(), rx=-70 + 25 * i, rz=18 * i), 110, yaw=30 * i, outline=0.05)) for i in range(6)]
    title = text_spr("РАЗБОГАТЕЙ" if RU else "GET RICH", 200, 960)
    rng = np.random.RandomState(7)
    parts = [(rng.uniform(0, 4), rng.uniform(-430, 430), rng.uniform(1500, 2300), rng.randint(0, 6), rng.uniform(0.7, 1.25)) for _ in range(46)]
    from PIL import ImageFont
    font = ImageFont.truetype(A.FONT, 150)

    def money(v):
        s = f"{int(v):,}".replace(",", " ")
        return "$" + s

    def frame(f):
        t = f / FPS
        c = bg(t)
        ground(c, 1500, ((255, 196, 92), (255, 222, 130)))
        back, front = [], []
        for t0, vx, vy, ci, sc in parts:
            lt = (t - t0 * 0.9) % 1.9
            if t < t0 * 0.25:
                continue
            x = 540 + vx * lt
            y = 1300 - vy * lt + 0.5 * 2600 * lt * lt
            if y > 1900:
                continue
            (front if vy * 1 - 2600 * lt < 0 else back).append((coin[ci], x, y, sc, lt * 300 * (1 if vx > 0 else -1)))
        for s, x, y, sc, r in back:
            paste(c, s, x, y, scale=sc, rot=r)
        bounce = 1 + 0.03 * math.sin(t * 16)
        paste(c, chest, 540, 1720, scale=spring(t, 0.5) * bounce, anchor="bottom", shadow=True)
        for s, x, y, sc, r in front:
            paste(c, s, x, y, scale=sc * 1.1, rot=r)
        # счётчик денег: растёт по экспоненте, как доход в тайкуне
        v = 10 ** (clamp((t - 0.3) / 3.0) * 6.0)
        if t > 3.3:
            v = 1_000_000
        txt = money(v)
        layer = Image.new("RGBA", (1000, 260), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        d.rounded_rectangle([20, 30, 980, 230], 100, fill=A.DARK + (255,))
        d.rounded_rectangle([32, 42, 968, 210], 86, fill=(57, 255, 20, 255) if t > 3.3 else (255, 255, 255, 255), outline=A.DARK + (255,), width=6)
        tw = font.getlength(txt)
        fo = font if tw < 860 else ImageFont.truetype(A.FONT, int(150 * 860 / tw))
        l, tp, r, b = fo.getbbox(txt)
        d.text((500 - (r - l) / 2 - l, 126 - (b - tp) / 2 - tp), txt, font=fo, fill=A.DARK + (255,))
        paste(c, title, 540, 340, scale=spring(t - 0.05))
        pop = 1 + (0.12 * math.exp(-(t - 3.3) * 7) if t > 3.3 else 0)
        paste(c, layer, 540, 620, scale=spring(t - 0.25, 0.4) * pop, rot=-2)
        flash(c, f)
        return c
    return 4.0, frame


def scene_end():
    base = A.gradient(W, H, [(0, "#7B2FF7"), (0.55, "#B354FF"), (1, "#FF7BB5")])
    S = 2700
    rays = A.rays(S, S, (S // 2, S // 2), 14, color=(255, 244, 190), alpha=60)
    glow = A.radial(W, H, (540, 1000), 620, "#FFFFFF", 0.25)
    chest = cached("chest_open_e", lambda: A.shot(MA.chest_open(), 640, yaw=-24, pitch=20))
    fox = spr("art_r_fox", 330, yaw=-35, pitch=10)
    dragon = spr("art_e_dragon", 340, yaw=30, pitch=10)
    drop = spr("art_c_drop", 170, yaw=-10, pitch=8)
    frog = spr("art_r_frog", 190, yaw=18, pitch=8)
    t1 = text_spr("CHRONO HEIST", 170, 980)
    t2 = text_spr("TYCOON", 190, 700, top="#FFFFFF", bottom="#7DF3FF")
    slogan = ribbon_spr("Укради. Защити. Разбогатей." if RU else "Steal. Defend. Get rich.", 62, 980)
    cta = text_spr("ИГРАЙ В ROBLOX" if RU else "PLAY ON ROBLOX", 110, 940, top="#FFFFFF", bottom="#FFE066")
    from PIL import ImageFont
    font = ImageFont.truetype(A.FONT, 62)
    q = "Chrono Heist Tycoon"
    pill = Image.new("RGBA", (900, 150), (0, 0, 0, 0))
    d = ImageDraw.Draw(pill)
    d.rounded_rectangle([6, 12, 894, 146], 66, fill=A.DARK + (255,))
    d.rounded_rectangle([10, 6, 890, 132], 62, fill=(255, 255, 255, 255), outline=A.DARK + (255,), width=6)
    d.ellipse([52, 40, 100, 88], outline=A.DARK + (255,), width=10)  # лупа
    d.line([94, 84, 118, 108], fill=A.DARK + (255,), width=12)

    def frame(f):
        t = f / FPS
        c = base.copy()
        _blit(c, rays.rotate(t * 8, resample=Image.BILINEAR), 540 - S // 2, 900 - S // 2)
        c.alpha_composite(glow)
        paste(c, t1, 540, 300, scale=spring(t - 0.05), rot=2)
        paste(c, t2, 540, 480, scale=spring(t - 0.25), rot=2)
        paste(c, slogan, 540, 640, scale=spring(t - 0.5, 0.35), rot=2)
        paste(c, fox, 180, 1240 + 10 * math.sin(t * 5), scale=spring(t - 0.5), anchor="bottom", shadow=True)
        paste(c, dragon, 900, 1240 + 10 * math.sin(t * 5 + 2), scale=spring(t - 0.6), anchor="bottom", shadow=True)
        paste(c, chest, 540, 1270, scale=0.8 * spring(t - 0.35) * (1 + 0.02 * math.sin(t * 9)), anchor="bottom", shadow=True)
        paste(c, drop, 350, 1300 + 8 * math.sin(t * 6 + 1), scale=spring(t - 0.7), anchor="bottom", shadow=True)
        paste(c, frog, 730, 1302 + 8 * math.sin(t * 6 + 3), scale=spring(t - 0.8), anchor="bottom", shadow=True)
        sparkles(c, [(150, 800, 24), (940, 820, 20), (540, 760, 16), (90, 1090, 14), (1000, 1050, 14)], t)
        paste(c, cta, 540, 1440, scale=spring(t - 1.0) * (1 + 0.03 * math.sin(t * 7)))
        # строка поиска: название печатается по буквам
        n = int(clamp((t - 1.5) / 0.9) * len(q))
        p = pill.copy()
        dd = ImageDraw.Draw(p)
        shown = q[:n]
        dd.text((150, 30), shown, font=font, fill=A.DARK + (255,))
        if n < len(q) or int(t * 3) % 2 == 0:
            cx = 150 + font.getlength(shown) + 8
            dd.rectangle([cx, 34, cx + 6, 100], fill=(123, 47, 247, 255))
        paste(c, p, 540, 1570, scale=spring(t - 1.3, 0.35))
        flash(c, f)
        return c
    return 4.0, frame


SCENES = [("hook", scene_hook), ("collection", scene_collection), ("defend", scene_defend), ("rich", scene_rich), ("end", scene_end)]
STILLS = {"hook": [20, 80], "collection": [40, 130], "defend": [60, 125], "rich": [50, 110], "end": [30, 100]}


# ---------- звук: простой бодрый луп 120 уд/мин, синтез numpy ----------
def audio(path, total):
    sr = 44100
    n = int(total * sr)
    out = np.zeros(n)
    beat = 0.5

    def add(sig, t0, vol=1.0):
        i = int(t0 * sr)
        if i >= n:
            return
        sig = sig[: n - i]
        out[i:i + len(sig)] += sig * vol

    def env(length, a=0.005, d=6.0):
        t = np.arange(int(length * sr)) / sr
        return t, np.minimum(1, t / a) * np.exp(-t * d)

    def kick():
        t, e = env(0.25, 0.002, 16)
        return np.sin(2 * np.pi * (48 * t + 60 * (1 - np.exp(-t * 30)) / 30 * 3)) * e

    def hat():
        t, e = env(0.06, 0.001, 70)
        return np.random.RandomState(1).uniform(-1, 1, len(t)) * e

    def clap():
        t, e = env(0.14, 0.001, 28)
        x = np.random.RandomState(2).uniform(-1, 1, len(t))
        return (x - np.convolve(x, np.ones(6) / 6, "same")) * e

    def note(freq, length=0.22, d=9.0, kind="pluck"):
        t, e = env(length, 0.004, d)
        if kind == "bass":
            return (np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t)) * e
        return (np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(4 * np.pi * freq * t) + 0.15 * np.sin(6 * np.pi * freq * t)) * e

    def hz(semi):
        return 261.63 * 2 ** (semi / 12)

    chords = [(0, 4, 7), (9 - 12, 0, 4), (5 - 12, 9 - 12, 0), (7 - 12, 11 - 12, 2)]  # C Am F G
    nb = int(total / beat) + 1
    for b in range(nb):
        t0 = b * beat
        ch = chords[(b // 4) % 4]
        add(kick(), t0, 0.9)
        add(hat(), t0 + beat / 2, 0.22)
        add(hat(), t0, 0.1)
        if b % 2 == 1:
            add(clap(), t0, 0.35)
        add(note(hz(ch[0] - 24) * 2, 0.4, 5, "bass"), t0, 0.5)
        add(note(hz(ch[0] - 24) * 2, 0.2, 9, "bass"), t0 + beat * 0.75, 0.35)
        arp = [ch[0], ch[1], ch[2], ch[1] + 12]
        for i in range(4):
            add(note(hz(arp[(i + b) % 4] + 12), 0.2, 11), t0 + i * beat / 4, 0.16)
    # акценты: «поп» на появлении существ, звон монет, финальный аккорд
    for i in range(5):
        add(note(hz(12 + (0, 4, 7, 12, 16)[i]), 0.5, 5), 3.5 + 0.5 + i, 0.5)
    for i in range(14):
        add(note(hz(24 + (0, 7, 12, 16)[i % 4]), 0.12, 22), 13.5 + 0.4 + i * 0.2, 0.18)
    for s in (0, 4, 7, 12):
        add(note(hz(s + 12), 1.6, 2.2), 17.5, 0.3)
    for t0 in (0, 3.5, 9.0, 13.5, 17.5):  # «вжух» на смене сцен
        t, e = env(0.35, 0.12, 9)
        x = np.random.RandomState(3).uniform(-1, 1, len(t))
        add(np.convolve(x, np.ones(24) / 24, "same") * e, max(0, t0 - 0.12), 0.9)
    out = np.tanh(out * 0.9)
    fade = int(0.6 * sr)
    out[-fade:] *= np.linspace(1, 0, fade)
    pcm = (out * 0.8 * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def encode_scene(name, dur, frame):
    tmp = os.path.join(OUT, f"_{LANG}_{name}.tmp.mp4")
    dst = os.path.join(OUT, f"_{LANG}_{name}.mp4")
    p = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                          "-c:v", "libx264", "-crf", "20", "-preset", "medium", "-pix_fmt", "yuv420p", "-r", str(FPS), tmp], stdin=subprocess.PIPE)
    for f in range(int(round(dur * FPS))):
        p.stdin.write(frame(f).convert("RGB").tobytes())
    p.stdin.close()
    if p.wait() != 0:
        raise SystemExit("ffmpeg: ошибка на сцене " + name)
    os.replace(tmp, dst)
    return dst


def main():
    only = sys.argv[3:] if len(sys.argv) > 3 else None
    if len(sys.argv) > 2 and sys.argv[2] == "stills":
        d = os.path.join(OUT, f"stills_{LANG}")
        os.makedirs(d, exist_ok=True)
        for name, make in SCENES:
            if only and name not in only:
                continue
            dur, frame = make()
            for f in STILLS[name]:
                frame(f).convert("RGB").resize((540, 960), Image.LANCZOS).save(os.path.join(d, f"{name}_{f:03d}.jpg"), quality=88)
            print("кадры:", name)
        return
    files, total = [], 0.0
    for name, make in SCENES:
        dur, frame = make()
        files.append(encode_scene(name, dur, frame))
        total += dur
        print("сцена:", name, dur)
    lst = os.path.join(OUT, f"_{LANG}_list.txt")
    open(lst, "w").write("".join(f"file '{f}'\n" for f in files))
    wav = os.path.join(OUT, f"_{LANG}.wav")
    audio(wav, total)
    silent = os.path.join(OUT, f"_{LANG}_silent.mp4")
    subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", silent])
    final = os.path.join(OUT, f"chrono_heist_promo1_{LANG}.mp4")
    subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-i", silent, "-i", wav, "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "128k",
                           "-shortest", "-movflags", "+faststart", final])
    print("готово:", final, f"{os.path.getsize(final) / 1e6:.1f} МБ")


if __name__ == "__main__":
    main()
