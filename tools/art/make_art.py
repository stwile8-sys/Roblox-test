#!/usr/bin/env python3
"""Картинки для страницы игры Chrono Heist Tycoon: иконка и три обложки (RU + EN).

Запуск: python3 tools/art/make_art.py [icon|main|heist|collection …]
Всё рисуется из наших же 3D-моделей (tools/models) программным рендером — без чужих картинок и шрифтов с логотипами.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from artlib import (T, cloud, finish, gradient, join, model, put, radial, rays, ribbon, shot, sparkle, text)  # noqa: E402
from meshlib import PAL, cyl, lathe, fillet, mix, rbox, sphere, torus, tube  # noqa: E402
import creatures  # noqa: E402

RARITY = {"common": "#C8D2E0", "rare": "#4DA3FF", "epic": "#B66BFF", "legendary": "#FFC53D", "chrono": "#00E5FF"}
_sprites = {}


def spr(name, px, yaw=-28, pitch=16):
    key = (name, px, yaw, pitch)
    if key not in _sprites:
        _sprites[key] = shot(model(name), px, yaw=yaw, pitch=pitch)
    return _sprites[key]


def chest_open(angle=62):
    return join(model("chest"), T(model("chestLid"), rx=angle, pos=(0, 3.5, 3.5)))


def coin():
    return {"Body": cyl(0.5, 0.14, 0.05, 14, "gold", steps=1), "Glow_FFE066": torus(0.34, 0.05, 14, 4).move(0, 0.15, 0)}


def coins(canvas, pts, size):
    for i, (x, y) in enumerate(pts):
        s = shot(T(coin(), rx=-62 + 16 * math.sin(i * 2.3), rz=25 * math.cos(i * 1.7)), int(size * (0.8 + 0.4 * ((i * 37) % 10) / 10)), yaw=20 * i, outline=0.05)
        put(canvas, s, x, y, shadow=False, anchor="center", rot=17 * i)


def figure(col, kind="thief"):
    """Простой игрок-человечек (не аватар Roblox): вор с повязкой несёт существо, защитник с дубинкой."""
    c = PAL[col]
    skin = mix(PAL["cream"], PAL["orange"], 0.18)
    dark = PAL["dark"]
    body = [rbox(1.9, 2.0, 1.15, 0.5, 2, c).move(0, 3.0, 0).grad(mix(c, dark, 0.3), c)]
    body.append(sphere(1.0, 14, 8, skin).scale(1, 0.95, 0.95).move(0, 4.85, 0))
    eye = []
    ez = -1.16 if kind == "thief" else -0.86
    for s in (-1, 1):
        eye.append(sphere(0.23, 8, 5, PAL["white"]).scale(1, 1.15, 0.6).move(s * 0.38, 4.9, ez))
        eye.append(sphere(0.115, 6, 4, dark).move(s * 0.38, 4.88, ez - 0.13))
    if kind == "thief":
        body.append(torus(0.93, 0.26, 16, 6, dark).scale(1, 1.0, 0.98).move(0, 4.9, 0))
        body.append(lathe(fillet([(0, 5.3), (1.02, 5.3), (0.9, 5.75), (0.4, 5.98), (0, 6.0)], 0.2), 14, color=dark))
        body.append(sphere(0.18, 6, 4, PAL["red"]).move(0, 6.05, 0))
        body.append(tube([(-0.25, 4.42, -0.9), (0, 4.36, -0.95), (0.25, 4.42, -0.9)], 0.05, 4, color=dark))
        arms = [[(-0.95, 3.7, 0), (-1.25, 4.9, -0.2), (-0.95, 6.2, -0.2)], [(0.95, 3.7, 0), (1.25, 4.9, -0.2), (0.95, 6.2, -0.2)]]
        legs = [[(-0.45, 2.1, 0), (-0.5, 1.2, -0.7), (-0.45, 0.35, -1.0)], [(0.45, 2.1, 0), (0.5, 1.4, 0.6), (0.45, 1.0, 1.4)]]
    else:
        body.append(lathe(fillet([(0, 5.15), (1.06, 5.15), (1.0, 5.6), (0.5, 5.95), (0, 6.0)], 0.2), 14, color="gold"))
        body.append(torus(1.05, 0.12, 16, 4, "orange").move(0, 5.2, 0))
        for s in (-1, 1):
            eye.append(rbox(0.42, 0.1, 0.1, 0.04, 1, dark).rot("z", -s * 22).move(s * 0.36, 5.17, -0.95))
        body.append(sphere(0.2, 8, 5, dark).scale(1.2, 0.8, 0.5).move(0, 4.4, -0.9))
        arms = [[(-0.95, 3.7, 0), (-1.3, 3.2, -0.7), (-1.2, 3.3, -1.5)], [(0.95, 3.7, 0), (1.5, 4.7, 0.1), (1.6, 5.9, -0.3)]]
        legs = [[(-0.45, 2.1, 0), (-0.5, 1.3, -0.8), (-0.45, 0.35, -1.1)], [(0.45, 2.1, 0), (0.5, 1.4, 0.6), (0.45, 1.0, 1.4)]]
    limb = []
    for a in arms:
        limb.append(tube(a, 0.3, 7, color=mix(c, PAL["white"], 0.15)))
        limb.append(sphere(0.34, 8, 5, skin).move(*a[-1]))
    for lg in legs:
        limb.append(tube(lg, 0.36, 7, color=mix(c, dark, 0.45)))
        limb.append(sphere(0.42, 8, 5, dark).scale(1, 0.75, 1.3).move(*lg[-1]))
    from meshlib import merge
    return {"Body": merge(body + limb), "Eye": merge(eye)}


def sky(w, h, stops, sun, ray_alpha=34):
    c = gradient(w, h, stops)
    c.alpha_composite(radial(w, h, sun, max(w, h) * 0.75, "#FFFFFF", 0.35))
    c.alpha_composite(rays(w, h, sun, 16, alpha=ray_alpha))
    return c


# ================= ИКОНКА =================
def icon():
    W = 1024
    c = gradient(W, W, [(0, "#7B2FF7"), (0.55, "#B354FF"), (1, "#FF7BB5")])
    c.alpha_composite(radial(W, W, (512, 470), 620, "#FFE066", 0.05))
    c.alpha_composite(rays(W, W, (512, 470), 14, color=(255, 244, 190), alpha=70, phase=0.3))
    c.alpha_composite(radial(W, W, (512, 470), 360, "#FFFFFF", 0.25))
    put(c, shot(chest_open(), 600, yaw=-24, pitch=20), 512, 700)
    put(c, spr("art_r_fox", 290, yaw=-35, pitch=10), 215, 690)
    put(c, spr("art_e_dragon", 300, yaw=30, pitch=10), 815, 690)
    put(c, spr("art_c_drop", 150, yaw=-10, pitch=8), 380, 725)
    put(c, spr("art_r_frog", 170, yaw=18, pitch=8), 655, 728)
    coins(c, [(150, 300), (890, 250), (240, 150), (770, 110)], 78)
    for x, y, s in ((180, 190, 26), (850, 170, 20), (905, 350, 16), (120, 330, 14), (512, 120, 18)):
        sparkle(c, x, y, s)
    text(c, "CHRONO", 512, 792, 150, max_w=700, rot=3)
    text(c, "HEIST", 512, 905, 150, max_w=560, top="#FFFFFF", bottom="#7DF3FF", rot=3)
    finish(c, os.path.join(HERE, "icon.png"), vignette=0.3)


# ================= ГЛАВНАЯ =================
def hub_scene():
    parts = [T(model("chestPedestal"), s=1.25), T(chest_open(58), s=1.9, pos=(0, 5.75, 0))]
    for i in range(44):
        parts.append(T(model("beltArc"), yaw=i * 360 / 44))
    riders = ["art_c_drop", "art_r_fox", "art_c_shroom", "art_e_dragon", "art_r_frog", "art_c_jelly", "art_e_hourglass", "art_r_whisper",
              "art_c_bubble", "art_e_phoenix", "art_r_beetle", "art_x_zero", "art_c_moss", "art_r_owl", "art_e_lynx", "art_l_whale"]
    for i, n in enumerate(riders):
        a = math.radians(i * 360 / len(riders) + 8)
        m = model(n)
        hgt = max(v.V[:, 1].max() for v in m.values())
        parts.append(T(m, s=5.2 / hgt, yaw=math.degrees(a) + 160, pos=(27 * math.sin(a), 1.2, -27 * math.cos(a))))
    parts.append(T(model("portalStart"), s=1.3, yaw=90, pos=(-27, 0.4, 0)))
    parts.append(T(model("portalEnd"), s=1.3, yaw=-90, pos=(27, 0.4, 0)))
    # травяной диск хаба
    disc = cyl(36, 2.0, 0.8, 40, "grass", steps=2).move(0, -2.0, 0)
    disc.paint_fn(lambda p: mix(PAL["grassLight"], PAL["grass"], min(1, math.hypot(p[0], p[2]) / 36) ** 2) if p[1] > -0.3 else PAL["grassDark"])
    parts.append({"Body": disc})
    return join(*parts)


def main_thumb(lang):
    W, H = 1920, 1080
    c = sky(W, H, [(0, "#2FB4FF"), (0.5, "#8CE3FF"), (0.8, "#D9F8FF"), (1, "#FFF1C9")], (1250, 420))
    for x, y, s in ((250, 620, 70), (1700, 250, 60), (980, 150, 46), (1500, 760, 80), (120, 900, 60)):
        cloud(c, x, y, s)
    # дальние острова
    isl = shot(join(model("islandMid"), T(model("tree"), s=1.6, pos=(-20, 38.6, 5)), T(model("tree"), s=1.2, pos=(16, 38.6, -12)),
                    T(model("wall2"), s=0.9, pos=(4, 38.6, 10)), T(model("beacon"), s=0.9, pos=(22, 38.6, 14))), 420, pitch=14, outline=0.008)
    put(c, isl, 1690, 560, shadow=False)
    put(c, isl, 1090, 330, height=170, shadow=False, flip=True)
    put(c, isl, 110, 520, height=230, shadow=False, flip=True)
    # хаб на большом острове
    hub = shot(hub_scene(), 1330, yaw=-22, pitch=27, outline=0.004)
    put(c, hub, 1180, 1075, shadow=False)
    # герои на переднем плане
    put(c, spr("art_e_dragon", 400, yaw=22, pitch=8), 300, 1090)
    put(c, spr("art_r_fox", 330, yaw=-30, pitch=8), 620, 1100)
    put(c, spr("art_l_owlking", 380, yaw=30, pitch=8), 1730, 1100)
    put(c, spr("art_c_drop", 170, yaw=-10, pitch=8), 95, 1085)
    coins(c, [(820, 640), (1560, 420), (1450, 300), (900, 480), (1640, 620), (760, 800)], 62)
    for x, y, s in ((1180, 330, 30), (1420, 520, 18), (930, 560, 16), (1560, 250, 14)):
        sparkle(c, x, y, s)
    text(c, "CHRONO HEIST", 600, 150, 190, max_w=1080, rot=2)
    text(c, "TYCOON", 430, 330, 190, max_w=700, top="#FFFFFF", bottom="#7DF3FF", rot=2)
    slogan = "Укради. Защити. Разбогатей." if lang == "ru" else "Steal. Defend. Get rich."
    ribbon(c, slogan, 520, 490, 62, max_w=980, rot=2)
    finish(c, os.path.join(HERE, "thumb_main.png" if lang == "ru" else "thumb_main_en.png"))


# ================= КРАЖА =================
def heist_thumb(lang):
    W, H = 1920, 1080
    c = sky(W, H, [(0, "#5B3BFF"), (0.45, "#B56BFF"), (0.75, "#FF9EC4"), (1, "#FFE066")], (1150, 620), ray_alpha=30)
    for x, y, s in ((300, 330, 60), (1650, 300, 70), (960, 250, 40)):
        cloud(c, x, y, s, alpha=150)
    # земля базы
    g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    d.ellipse([-300, 820, W + 300, 1500], fill=(125, 216, 122, 255), outline=(42, 33, 64, 255), width=8)
    d.ellipse([-200, 850, W + 200, 1500], fill=(168, 238, 140, 255))
    c.alpha_composite(g)
    # стена базы и распахнутые ворота позади
    put(c, spr("wall3", 760, yaw=-18, pitch=8), 330, 900, shadow=False)
    put(c, spr("gate3", 760, yaw=-18, pitch=8), 1030, 842, shadow=False)
    put(c, spr("beacon", 520, yaw=-18, pitch=8), 1560, 880, shadow=False)
    put(c, spr("pedestalRich", 300, yaw=-20, pitch=14), 250, 960)
    put(c, shot(model("lockButton"), 250, yaw=-20, pitch=20, tint={"Button": "#FF2E63"}), 1700, 1000)
    put(c, spr("mine", 150, yaw=-20, pitch=16), 1420, 1040)
    # защитник с дубинкой гонится
    defender = join(figure("orange", "defender"), T(model("club"), s=0.9, rx=-35, pos=(1.6, 5.6, -0.4)))
    put(c, shot(T(defender, rx=-10), 470, yaw=58, pitch=6), 560, 1050)
    # вор уносит редкое существо
    rare = model("art_l_owlking")
    thief = join(figure("violet", "thief"), T(rare, s=0.62, pos=(0, 6.5, -0.2)))
    halo = radial(W, H, (1215, 450), 340, "#FFE066", 0.2)
    c.alpha_composite(halo)
    c.alpha_composite(rays(W, H, (1215, 450), 12, color=(255, 240, 170), alpha=46))
    put(c, shot(T(thief, rx=-12), 760, yaw=40, pitch=6), 1150, 1065)
    # линии скорости
    sp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(sp)
    for i, (x, y, ln) in enumerate(((760, 520, 170), (800, 640, 120), (740, 760, 190), (820, 880, 110), (700, 420, 100))):
        d.rounded_rectangle([x - ln, y - 7, x, y + 7], 7, fill=(255, 255, 255, 200))
    c.alpha_composite(sp)
    coins(c, [(880, 960), (800, 1010), (960, 1030), (1400, 700), (1480, 560)], 60)
    for x, y, s in ((1330, 300, 28), (930, 330, 20), (1250, 180, 16), (1010, 500, 14)):
        sparkle(c, x, y, s)
    msg = "КРАДИ САМЫХ РЕДКИХ!" if lang == "ru" else "STEAL THE RAREST!"
    text(c, msg, 960, 140, 170, max_w=1760, rot=1.5)
    finish(c, os.path.join(HERE, "thumb_heist.png" if lang == "ru" else "thumb_heist_en.png"))


# ================= КОЛЛЕКЦИЯ =================
def collection_thumb(lang):
    W, H = 1920, 1080
    c = gradient(W, H, [(0, "#3A1E9C"), (0.5, "#7B2FF7"), (1, "#FF7BB5")])
    c.alpha_composite(radial(W, H, (960, 560), 1100, "#00E5FF", 0.55))
    c.alpha_composite(rays(W, H, (960, 1250), 22, alpha=26))
    defs = creatures.load_defs()
    by = {r: [d for d in defs if d["rarity"] == r and not d["id"].startswith("s")] for r in RARITY}
    rows = [("legendary", 455, 285, 300), ("chrono", 610, 235, 285), ("epic", 760, 205, 232), ("rare", 905, 178, 188), ("common", 1062, 158, 186)]
    for ri, (rar, base, size, step) in enumerate(rows):
        ds = by[rar]
        n = len(ds)
        x0 = W / 2 - step * (n - 1) / 2 + (step * 0.0 if ri % 2 == 0 else 0)
        col = RARITY[rar]
        for i, d in enumerate(ds):
            x = x0 + step * i
            y = base + 16 * math.sin(i * 1.9 + ri)
            glow = radial(W, H, (x, y - size * 0.42), size * 0.78, col, 0.35)
            c.alpha_composite(glow)
            s = spr("art_" + d["id"], size, yaw=-18 + 36 * (i / max(1, n - 1)) , pitch=10)
            k = size / max(s.width, s.height)
            put(c, s, x, y, height=int(s.height * k))
    for x, y, s in ((140, 300, 24), (1790, 330, 22), (330, 170, 14), (1600, 170, 16), (80, 620, 14), (1850, 640, 14)):
        sparkle(c, x, y, s)
    msg = "40 СУЩЕСТВ • 5 РЕДКОСТЕЙ" if lang == "ru" else "40 CREATURES • 5 RARITIES"
    text(c, msg, 960, 105, 140, max_w=1780, rot=0)
    finish(c, os.path.join(HERE, "thumb_collection.png" if lang == "ru" else "thumb_collection_en.png"), vignette=0.15)


JOBS = {"icon": lambda: icon(), "main": lambda: (main_thumb("ru"), main_thumb("en")), "heist": lambda: (heist_thumb("ru"), heist_thumb("en")),
        "collection": lambda: (collection_thumb("ru"), collection_thumb("en"))}

if __name__ == "__main__":
    for j in (sys.argv[1:] or list(JOBS)):
        JOBS[j]()
        print("готово:", j)
