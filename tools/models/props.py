"""Модели мира Chrono Heist Tycoon: пьедесталы, острова, стены, мост, кристаллы, декор, конвейер, ловушки.

Каждая функция возвращает Model (узлы: Body + Glow_RRGGBB[_Tnn] для светящихся частей).
Координаты: Y вверх, перед на −Z, стады. build.py сам ставит точку опоры в «низ по центру».
"""
import math

import numpy as np

from meshlib import (PAL, arc, blob, build, col, cone, crystal, cyl, fillet, lathe, merge, mix, rbox, sphere, torus,
                     tube)


class Model:
    def __init__(self):
        self.parts = {}

    def add(self, mesh, glow=None, t=None):
        """glow — hex-цвет свечения (узел Glow_…), t — прозрачность в процентах."""
        name = "Body"
        if glow:
            g = glow if glow.startswith("#") else "#%02X%02X%02X" % tuple(int(round(x * 255)) for x in PAL[glow])
            name = "Glow_" + g.lstrip("#").upper() + (f"_T{t}" if t else "")
            mesh.paint(mix(col(g), PAL["white"], 0.45))
        self.parts.setdefault(name, []).append(mesh)
        return mesh

    def nodes(self):
        return {k: merge(v) for k, v in self.parts.items()}


def ring_pos(n, R, y=0.0, phase=0.0):
    return [(R * math.cos(2 * math.pi * i / n + phase), y, R * math.sin(2 * math.pi * i / n + phase)) for i in range(n)]


# ================= 1. Пьедесталы =================
def pedestal(kind="normal"):
    m = Model()
    rich, decoy = kind == "rich", kind == "decoy"
    c_base = "violet" if rich else "orange"
    c_body = "gold" if rich else "cream"
    c_top = mix(PAL["gold"], PAL["white"], 0.35) if rich else PAL["cream"]
    m.add(cyl(3.5, 0.85, 0.3, 20, c_base, r2=3.3)).grad(mix(col(c_base), PAL["dark"], 0.35), c_base)
    neck = fillet([(0, 0.7), (2.9, 0.7), (2.0, 1.4), (1.9, 2.2), (2.8, 2.9), (0, 2.9)], 0.5, 3)
    m.add(lathe(neck, 20, color=c_body)).grad(mix(col(c_body), PAL["orange"], 0.25), c_body)
    m.add(cyl(3.1, 0.7, 0.28, 20, c_top).move(0, 2.8, 0))
    m.add(torus(2.05, 0.22, 20, 6, "red" if rich else "gold").move(0, 1.8, 0))
    m.add(torus(2.35, 0.13, 20, 6).move(0, 3.5, 0), glow="violet" if decoy else ("gold" if rich else "chrono"))
    if rich:
        for x, y, z in ring_pos(4, 2.1, 1.25, math.pi / 4):
            m.add(crystal(0.38, 1.1, 4, 0.5, 0.5).move(x, y, z), glow="chrono")
        for x, y, z in ring_pos(6, 3.05, 3.15):
            m.add(sphere(0.2, 5, 3, "red").move(x, y, z))
    if decoy:
        for x, y, z in ring_pos(3, 2.6, 2.55, 0.5):
            m.add(cone(0.25, 0.7, 5, "dark").rot("x", 180).move(x, y + 0.3, z))
    return m


# ================= 2. Парящие острова =================
def island(R, seed=1, ncr=6):
    m = Model()
    gh = max(2.2, R * 0.04)
    depth = R * 0.42
    lob = lambda th, r, y: 1.03 + 0.02 * math.sin(5 * th + seed) + 0.012 * math.sin(11 * th + 2.3 * seed)
    # травяная шапка: плоский верх на y=0
    gp = fillet([(0, 0), (R * 0.45, 0), (R * 0.8, 0), (R, 0), (R, -gh), (R * 0.88, -gh * 1.25), (0, -gh * 1.25)],
                [0, 0, 0, gh * 0.7, gh * 0.6, 0, 0], 3)
    grass = lathe(gp, 44, color="grass", radial=lob)

    def gcol(p):
        if p[1] > -0.02:
            rr = min(1.0, math.hypot(p[0], p[2]) / R)
            return mix(PAL["grassLight"], PAL["grass"], rr ** 1.5)
        return mix(PAL["grass"], PAL["grassDark"], min(1.0, -p[1] / gh))
    m.add(grass.paint_fn(gcol))
    # «потёки» травы по краю
    n = 14
    for i in range(n):
        th = 2 * math.pi * (i + 0.37 * math.sin(i * 1.7 + seed)) / n
        s = gh * (0.75 + 0.3 * math.sin(i * 2.1 + seed))
        b = blob(1.0, seed + i, 0.12, 8, 5).scale(s * 1.5, s * 1.2, s * 1.5)
        b.move(R * 0.985 * math.cos(th), -gh * 0.95, R * 0.985 * math.sin(th))
        m.add(b.grad("grassDark", "grass"))
    # земляной низ
    dp = fillet([(0, -gh * 0.5), (R * 0.9, -gh * 0.5), (R * 0.84, -depth * 0.3), (R * 0.6, -depth * 0.68),
                 (R * 0.3, -depth * 0.92), (0, -depth)], [0, R * 0.05, R * 0.2, R * 0.2, R * 0.15, 0], 3)
    lump = lambda th, r, y: 1 + 0.05 * math.sin(3 * th + seed * 1.3) + 0.035 * math.sin(7 * th + y * 0.09 + seed)
    dirt = lathe(dp, 30, crease=75, color="dirt", radial=lump)

    def dcol(p):
        t = min(1.0, max(0.0, (-p[1] - gh * 0.5) / (depth - gh * 0.5)))
        c = mix(PAL["dirt"], PAL["dirtDark"], t ** 0.8)
        band = math.exp(-((t - 0.28) / 0.07) ** 2)
        return mix(c, PAL["woodLight"], 0.35 * band)
    m.add(dirt.paint_fn(dcol))

    def surf(r):  # глубина земляного низа на радиусе r
        t = min(1.0, r / (R * 0.88))
        return -depth * math.cos(t * math.pi / 2) ** 0.8
    # камни на боку
    for i in range(5):
        th = 1.1 + i * 2 * math.pi / 5 + 0.4 * math.sin(i + seed)
        rr = R * (0.62 + 0.08 * math.sin(i * 3 + seed))
        s = R * 0.07
        b = blob(1.0, seed * 7 + i, 0.2, 8, 5).scale(s, s * 0.8, s).move(rr * math.cos(th), surf(rr) * 0.93, rr * math.sin(th))
        m.add(b.grad("stoneDark", "stone"))
    # кристаллы снизу
    for i in range(ncr):
        th = 0.5 + i * 2 * math.pi / ncr + 0.5 * math.sin(i * 1.3 + seed)
        rr = R * (0.15 + 0.4 * ((i * 0.618 + seed * 0.21) % 1))
        h = R * (0.13 + 0.09 * ((i * 0.37 + seed * 0.4) % 1))
        c = crystal(h / 4.5, h, 6, 0.35, 0.2).rot("x", 180).rot("z", 12 * math.sin(i * 2.2)).rot("y", i * 50)
        c.move(rr * math.cos(th), surf(rr) * 0.9, rr * math.sin(th))
        m.add(c, glow="chrono" if i % 3 else "violet")
    return m


# ================= 3. Стены и ворота =================
WL, WH, WT = 39.0, 14.0, 2.0


def wall(level):
    m = Model()
    if level == 1:  # дерево: частокол из досок
        n = 9
        w = WL / n
        for i in range(n):
            h = WH - (0.0 if i % 2 == 0 else 0.9) - 0.3 * math.sin(i * 1.9) ** 2
            c = "woodLight" if i % 2 == 0 else "wood"
            m.add(rbox(w - 0.12, h, 1.3, 0.4, 1, c).move(-WL / 2 + w * (i + 0.5), h / 2, 0)).grad(mix(col(c), PAL["woodDark"], 0.45), c)
        for y in (3.4, 10.2):
            m.add(rbox(WL, 1.1, WT, 0.3, 1, "woodDark").move(0, y, 0))
            for i in range(n):
                m.add(sphere(0.22, 6, 4, "gold").scale(1, 1, 0.6).move(-WL / 2 + w * (i + 0.5), y, -WT / 2))
    elif level == 2:  # камень: крупная кладка
        rows, rh = 3, WH / 3
        tones = [PAL["stone"], mix(PAL["stone"], PAL["stoneDark"], 0.4), mix(PAL["stone"], PAL["cream"], 0.4)]
        k = 0
        for r in range(rows):
            xs = [-WL / 2 + 7.8 * i for i in range(6)] if r % 2 == 0 else [-WL / 2, -WL / 2 + 3.9] + [-WL / 2 + 3.9 + 7.8 * i for i in range(1, 5)] + [WL / 2]
            for a, b in zip(xs[:-1], xs[1:]):
                c = tones[(k * 7 + r) % 3]; k += 1
                m.add(rbox(b - a - 0.14, rh - 0.14, WT, 0.45, 1, c).move((a + b) / 2, rh * (r + 0.5), 0)).grad(mix(c, PAL["stoneDark"], 0.3), c)
        for i, x in enumerate((-13.0, 4.5, 15.5)):
            m.add(blob(1.0, 30 + i, 0.2, 8, 5, "grass").scale(1.6, 0.6, 1.0).move(x, WH - 0.5, 0)).grad("grassDark", "grassLight")
    elif level == 3:  # металл: панели с заклёпками
        m.add(rbox(WL, 1.2, WT, 0.3, 1, "metalDark").move(0, 0.6, 0))
        for i in range(3):
            x = -13.0 + 13.0 * i
            m.add(rbox(11.4, 12.4, 1.3, 0.7, 2, "metal").move(x, 7.5, 0)).grad("metalDark", mix(PAL["metal"], PAL["white"], 0.3))
            for sx in (-4.6, 4.6):
                for sy in (2.4, 12.6):
                    for sz in (-0.62, 0.62):
                        m.add(sphere(0.3, 6, 4, "cream").scale(1, 1, 0.5).move(x + sx, sy, sz))
        for x in (-19.0, -6.5, 6.5, 19.0):
            m.add(rbox(1.0, WH, WT, 0.35, 1, "metalDark").move(x, WH / 2, 0))
        m.add(rbox(WL - 1, 0.7, 1.5, 0.25, 1, "orange").move(0, 7.5, 0))
    elif level == 4:  # укреплённая сталь: раскосы, шипы
        m.add(rbox(WL, 1.6, WT, 0.35, 1, "steelDark").move(0, 0.8, 0))
        m.add(rbox(WL, 1.2, WT, 0.35, 1, "steelDark").move(0, 12.6, 0))
        for i in range(3):
            x = -13.0 + 13.0 * i
            m.add(rbox(11.6, 11.0, 1.2, 0.5, 1, "steel").move(x, 6.9, 0)).grad("steelDark", "steel")
            for sgn in (-1, 1):
                m.add(rbox(14.2, 0.9, 1.7, 0.3, 1, "metalDark").rot("z", 40 * sgn).move(x, 6.9, 0))
            m.add(cyl(1.3, 2.1, 0.3, 8, "gold").rot("x", 90).move(x, 6.9, -1.05))
        for x in (-19.0, -6.5, 6.5, 19.0):
            m.add(rbox(1.4, 12.8, WT, 0.4, 1, "steelDark").move(x, 6.4, 0))
            m.add(cone(0.6, 1.2, 6, "red").move(x, 12.8, 0))
        m.add(rbox(WL - 0.6, 0.45, WT + 0.06, 0.15, 1, "red").move(0, 1.9, 0))
    else:  # хроно-барьер: пилоны + энергетическое поле
        for x in (-18.3, 18.3):
            m.add(cyl(1.2, 12.2, 0.4, 10, "violet", r2=0.85).move(x, 0, 0)).grad("dark", "violet")
            m.add(torus(1.05, 0.22, 10, 6, "gold").move(x, 4, 0))
            m.add(torus(0.95, 0.22, 10, 6, "gold").move(x, 9, 0))
            m.add(crystal(0.6, 2.1, 6, 0.45, 0.3).move(x, 11.9, 0), glow="chrono")
        m.add(rbox(WL, 1.0, WT, 0.35, 1, "dark").move(0, 0.5, 0))
        m.add(rbox(35.2, 0.5, 1.0, 0.2, 1, "violet").move(0, 12.0, 0))
        m.add(rbox(35.0, 10.8, 0.5, 0.2, 1).move(0, 6.4, 0), glow="chrono", t=45)
        for x in (-9.0, 0.0, 9.0):
            m.add(rbox(0.35, 10.6, 0.8, 0.15, 1).move(x, 6.4, 0), glow="violet")
            m.add(crystal(0.7, 1.4, 4, 0.5, 0.5).rot("x", 90).move(x, 6.4, -0.7), glow="gold")
    return m


GATE = {
    1: ("woodLight", "wood", "woodDark", "orange", "gold"),
    2: ("stone", "stoneDark", "wood", "stoneDark", "orange"),
    3: ("metal", "metalDark", "metalDark", "orange", "chrono"),
    4: ("steel", "steelDark", "steelDark", "red", "gold"),
    5: ("violet", "dark", None, "gold", "chrono"),
}


def gate(level):
    m = Model()
    c1, c2, cd, ct, cg = GATE[level]
    # боковые простенки
    for s in (-1, 1):
        for j in range(2):
            c = c1 if j == 0 else mix(col(c1), col(c2), 0.5)
            m.add(rbox(3.5, 12.6 - j * 0.8, 1.6, 0.45, 1, c).move(s * (14.2 + j * 3.5), (12.6 - j * 0.8) / 2, 0)).grad(c2, c)
        # столбы
        m.add(rbox(3.0, WH - 1.2, WT, 0.6, 2, c1).move(s * 10.8, (WH - 1.2) / 2, 0)).grad(c2, c1)
        m.add(rbox(3.6, 1.0, WT + 0.3, 0.3, 1, ct).move(s * 10.8, 0.5, 0))
        m.add(cyl(1.3, 0.9, 0.3, 10, ct, r2=0.9).move(s * 10.8, WH - 1.3, 0))
        m.add(sphere(0.55, 8, 5).move(s * 10.8, WH - 0.35, 0), glow=cg)
    # перемычка-арка
    m.add(rbox(19.4, 2.2, 1.8, 0.7, 2, c2).move(0, 11.4, 0)).grad(c2, c1)
    m.add(crystal(0.9, 1.9, 4, 0.5, 0.5).rot("x", 90).move(0, 11.4, -0.95), glow=cg)
    # створки
    for s in (-1, 1):
        if cd is None:
            m.add(rbox(9.1, 10.1, 0.5, 0.2, 1).move(s * 4.65, 5.15, 0), glow="chrono", t=45)
            m.add(rbox(0.3, 10.1, 0.8, 0.12, 1).move(s * 0.2, 5.15, 0), glow="violet")
        else:
            m.add(rbox(9.1, 10.1, 1.0, 0.4, 2, cd).move(s * 4.65, 5.15, 0)).grad(mix(col(cd), PAL["dark"], 0.3), cd)
            for y in (2.2, 8.2):
                m.add(rbox(9.2, 0.8, 1.25, 0.25, 1, ct).move(s * 4.65, y, 0))
            m.add(torus(0.55, 0.14, 10, 5, "gold").rot("x", 90).move(s * 1.4, 5.2, -0.62))
    return m


# ================= 4. Мост =================
def bridge():
    m = Model()
    L, W = 30.0, 14.0
    for x in (-5.4, 5.4):
        m.add(rbox(1.2, 1.2, L, 0.3, 1, "woodDark").move(x, 0.6, 0))
    n = 10
    for i in range(n):
        c = "woodLight" if i % 2 == 0 else "wood"
        m.add(rbox(W - 0.4 - 0.5 * (i % 2), 0.75, L / n - 0.16, 0.26, 1, c).move(0, 1.5, -L / 2 + L / n * (i + 0.5)))
    pz = [-13.6, -4.6, 4.6, 13.6]
    for s in (-1, 1):
        x = s * (W / 2 - 0.75)
        for z in pz:
            m.add(rbox(0.95, 4.6, 0.95, 0.3, 1, "woodDark").move(x, 3.4, z)).grad("woodDark", "wood")
            m.add(sphere(0.62, 8, 5, "gold").move(x, 5.95, z))
        for y, r, sag, c in ((5.0, 0.26, 0.9, "cream"), (3.3, 0.2, 0.6, "orange")):
            path = []
            for a, b in zip(pz[:-1], pz[1:]):
                for k in range(4):
                    t = k / 4
                    path.append((x, y - sag * 4 * t * (1 - t), a + (b - a) * t))
            path.append((x, y, pz[-1]))
            m.add(tube(path, r, 6, color=c))
    return m


# ================= 5. Кристаллы =================
def crystal_hub():
    m = Model()
    f = lambda th, r, y: 1 + 0.07 * math.sin(3 * th) + 0.04 * math.sin(5 * th + 1)
    base = lathe(fillet([(0, 0), (5.0, 0), (4.4, 1.2), (2.6, 2.3), (0, 2.5)], 0.6), 16, color="stone", radial=f)
    m.add(base.grad("stoneDark", "stone"))
    m.add(torus(4.0, 0.3, 20, 6, "gold").move(0, 1.5, 0))
    m.add(crystal(2.5, 11.0, 6, 0.3, 0.28).move(0, 3.9, 0), glow="chrono")
    m.add(torus(3.3, 0.16, 24, 5).rot("x", 14).move(0, 9.2, 0), glow="gold")
    for i, (x, y, z) in enumerate(ring_pos(3, 4.4, 0, 0.6)):
        m.add(crystal(0.75, 3.2, 6, 0.35, 0.35).rot("z", 10 if i % 2 else -12).move(x, 5.2 + 1.3 * i, z), glow="violet")
    for i, (x, y, z) in enumerate(ring_pos(5, 3.6, 0, 0.2)):
        m.add(crystal(0.5, 1.9, 5, 0.4, 0.2).rot("x", 18).rot("y", -math.degrees(math.atan2(z, x)) + 90).move(x, 1.2, z), glow="chrono")
    return m


def crystal_small(kind):
    m = Model()
    if kind == "A":
        m.add(blob(1.0, 5, 0.2, 8, 5, "stone").scale(1.0, 0.45, 1.0).move(0, 0.3, 0)).grad("stoneDark", "stone")
        m.add(crystal(0.6, 2.6, 6, 0.35, 0.2).rot("z", 8).move(0, 0.2, 0), glow="chrono")
    elif kind == "B":
        m.add(blob(1.0, 6, 0.2, 8, 5, "stone").scale(1.4, 0.45, 1.2).move(0, 0.3, 0)).grad("stoneDark", "stone")
        for h, r, tz, tx, x, z in ((3.0, 0.62, 0, 0, 0, 0), (2.0, 0.48, -24, 6, 0.6, 0.2), (1.6, 0.42, 22, -14, -0.6, -0.2)):
            m.add(crystal(r, h, 6, 0.35, 0.2).rot("z", tz).rot("x", tx).move(x, 0.2, z), glow="violet")
    else:
        m.add(blob(1.0, 7, 0.22, 10, 6, "stone").scale(2.0, 0.6, 1.8).move(0, 0.4, 0)).grad("stoneDark", "stone")
        spec = ((4.2, 0.8, 0, 0, 0, 0, "chrono"), (2.8, 0.6, -26, 8, 0.9, 0.3, "chrono"), (2.4, 0.55, 24, -12, -0.9, -0.2, "violet"),
                (1.8, 0.45, 10, 30, 0.2, 0.9, "gold"), (1.6, 0.42, -8, -32, -0.2, -0.9, "violet"))
        for h, r, tz, tx, x, z, c in spec:
            m.add(crystal(r, h, 6, 0.35, 0.2).rot("z", tz).rot("x", tx).move(x, 0.3, z), glow=c)
    return m


# ================= 6. Декор =================
def tree():
    m = Model()
    trunk = lathe(fillet([(0, 0), (1.25, 0), (0.75, 1.4), (0.6, 4.4), (0.95, 5.6), (0, 5.6)], 0.5), 10, color="wood")
    m.add(trunk.grad("woodDark", "woodLight"))
    for r, x, y, z, c0, c1, sd in ((3.3, 0, 7.4, 0, "grassDark", "grass", 1), (2.3, 1.9, 8.9, 0.7, "grass", "grassLight", 2),
                                   (2.2, -2.0, 8.1, -0.9, "grassDark", "grass", 3), (1.7, -0.3, 10.2, 0.2, "grass", "grassLight", 4),
                                   (1.8, 0.6, 7.0, -2.2, "grassDark", "grass", 5)):
        m.add(blob(r, sd, 0.1, 12, 7).scale(1, 0.88, 1).move(x, y, z)).grad(c0, c1)
    for x, y, z in ((2.6, 7.2, -1.6), (-2.9, 7.3, 0.9), (0.4, 9.3, -2.2), (1.3, 6.3, 2.4)):
        m.add(sphere(0.42, 8, 5, "orange").move(x, y, z))
    return m


def bush():
    m = Model()
    for r, x, y, z, sd in ((1.5, 0, 1.15, 0, 11), (1.1, 1.3, 0.85, 0.3, 12), (1.0, -1.25, 0.8, -0.2, 13), (0.9, 0.2, 0.75, -1.1, 14)):
        m.add(blob(r, sd, 0.12, 10, 6).scale(1, 0.8, 1).move(x, y, z)).grad("grassDark", "grassLight")
    for x, y, z in ((0.7, 1.9, -0.9), (-0.8, 1.7, 0.7), (1.6, 1.3, -0.5), (-1.5, 1.2, -0.8), (0.1, 2.25, 0.4)):
        m.add(sphere(0.24, 6, 4, "red").move(x, y, z))
    return m


def lantern():
    m = Model()
    m.add(cyl(0.9, 0.5, 0.2, 10, "dark", r2=0.7))
    m.add(torus(0.62, 0.14, 10, 5, "orange").move(0, 0.6, 0))
    m.add(cyl(0.24, 4.8, 0.1, 8, "dark", r2=0.2).move(0, 0.4, 0))
    m.add(cyl(0.7, 0.35, 0.12, 10, "dark", r2=0.85).move(0, 5.1, 0))
    m.add(sphere(0.85, 12, 7).scale(1, 1.1, 1).move(0, 6.2, 0), glow="gold")
    for x, y, z in ring_pos(4, 0.83, 0, math.pi / 4):
        m.add(tube([(x, 5.4, z), (x * 1.08, 6.2, z * 1.08), (x * 0.75, 7.0, z * 0.75)], 0.08, 4, color="dark"))
    m.add(lathe(fillet([(0, 6.9), (1.15, 6.9), (0.9, 7.25), (0.25, 7.75), (0, 7.8)], 0.15), 10, color="orange"))
    m.add(sphere(0.2, 6, 4, "gold").move(0, 7.9, 0))
    return m


def crate():
    m = Model()
    m.add(rbox(3.0, 3.0, 3.0, 0.3, 2, "woodLight").move(0, 1.5, 0)).grad("wood", "woodLight")
    for y in (0.55, 2.45):
        m.add(rbox(3.2, 0.55, 3.2, 0.2, 1, "woodDark").move(0, y, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.add(rbox(0.55, 3.05, 0.55, 0.2, 1, "woodDark").move(sx * 1.33, 1.5, sz * 1.33))
    m.add(rbox(0.9, 0.9, 0.3, 0.2, 1, "gold").move(0, 1.5, -1.5))
    m.add(sphere(0.2, 6, 4, "dark").scale(1, 1, 0.5).move(0, 1.5, -1.66))
    return m


def rock():
    m = Model()
    for r, x, y, z, sd in ((1.7, 0, 1.05, 0, 21), (1.1, 1.5, 0.65, 0.5, 22), (0.8, -1.4, 0.5, -0.5, 23)):
        m.add(blob(r, sd, 0.22, 10, 6, freq=2.0).scale(1, 0.7, 1).move(x, y, z)).grad("stoneDark", mix(PAL["stone"], PAL["cream"], 0.3))
    m.add(blob(0.7, 24, 0.15, 8, 5).scale(1, 0.35, 1).move(-0.2, 2.15, 0.1)).grad("grass", "grassLight")
    return m


def mushroom():
    m = Model()
    m.add(lathe(fillet([(0, 0), (0.95, 0), (0.6, 1.2), (0.65, 2.2), (0, 2.2)], 0.4), 12, color="cream")).grad(mix(PAL["cream"], PAL["orange"], 0.3), "cream")
    cap = fillet([(0, 1.9), (1.6, 1.8), (2.2, 2.0), (2.05, 2.8), (1.2, 3.6), (0, 3.85)], [0, 0.2, 0.3, 0.5, 0.6, 0], 3)
    m.add(lathe(cap, 16, crease=75, color="red")).grad(mix(PAL["red"], PAL["dark"], 0.25), mix(PAL["red"], PAL["pink"], 0.3))
    for th, rr, y, s in ((0.3, 1.75, 2.75, 0.42), (2.2, 1.7, 2.8, 0.36), (4.2, 1.72, 2.78, 0.4), (1.3, 0.95, 3.52, 0.34), (3.4, 0.9, 3.55, 0.3), (5.4, 1.0, 3.5, 0.3)):
        m.add(sphere(s, 8, 4, "cream").scale(1, 0.45, 1).move(rr * math.cos(th), y, rr * math.sin(th)))
    return m


# ================= 7. Конвейер и портал =================
def conveyor():
    """Секция 12×1.4×6: лента идёт вдоль +X, верх ленты на y = 1.2."""
    m = Model()
    L = 12.0
    m.add(rbox(L, 0.4, 5.0, 0.15, 1, "dark").move(0, 1.0, 0))
    for s in (-1, 1):
        m.add(rbox(L, 0.8, 0.7, 0.25, 1, "metal").move(0, 1.0, s * 2.65)).grad("metalDark", "metal")
        m.add(rbox(L, 0.22, 0.5, 0.1, 1, "orange").move(0, 1.42, s * 2.65))
        for x in (-4.6, 4.6):
            m.add(rbox(0.7, 0.8, 0.7, 0.2, 1, "metalDark").move(x, 0.4, s * 2.5))
    for x in (-4.0, 0.0, 4.0):
        for s in (-1, 1):
            m.add(rbox(2.3, 0.1, 0.5, 0.05, 1, "gold").rot("y", -s * 38).move(x, 1.2, s * 0.72))
    for x in (-5.7, 5.7):
        m.add(cyl(0.6, 5.0, 0.15, 8, "metalDark").rot("x", 90).move(x, 0.75, -2.5))
    return m


def portal():
    """Арка-портал, из которой выходят артефакты. Проём смотрит на −Z."""
    m = Model()
    m.add(rbox(13.0, 0.9, 4.4, 0.35, 1, "stoneDark").move(0, 0.45, 0))
    m.add(rbox(11.0, 0.6, 3.4, 0.25, 1, "stone").move(0, 1.1, 0))
    path = [(-4.6, 1.2, 0), (-4.6, 4.0, 0)] + [(x, y + 6.4, 0) for x, y, _ in arc(4.6, 180, 0, 12)] + [(4.6, 4.0, 0), (4.6, 1.2, 0)]
    m.add(tube(path, 1.05, 8, color="violet", crease=50)).grad("dark", "violet")
    for a in (150, 90, 30):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        m.add(torus(1.2, 0.26, 10, 5, "gold").rot("x", 90).rot("z", a).move(4.6 * ca, 6.4 + 4.6 * sa, 0))
    for s in (-1, 1):
        m.add(torus(1.2, 0.26, 10, 5, "gold").move(s * 4.6, 3.0, 0))
        m.add(crystal(0.5, 1.6, 6, 0.4, 0.3).move(s * 6.0, 1.3, -1.1), glow="chrono")
    m.add(crystal(0.9, 2.6, 6, 0.4, 0.35).move(0, 11.7, 0), glow="gold")
    m.add(sphere(1.0, 16, 8).scale(3.8, 4.9, 0.14).move(0, 6.1, 0), glow="chrono", t=35)
    for R in (2.9, 1.7):
        m.add(torus(R, 0.13, 20, 5).scale(1, 1, 1.2).rot("x", 90).move(0, 6.2, 0), glow="violet")
    return m


# ================= 8. Верстак, маяк, ловушки =================
def bench():
    m = Model()
    m.add(rbox(6.0, 0.55, 3.0, 0.22, 2, "woodLight").move(0, 2.8, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.add(rbox(0.55, 2.6, 0.55, 0.2, 1, "woodDark").move(sx * 2.55, 1.3, sz * 1.1))
    m.add(rbox(5.3, 0.3, 2.3, 0.12, 1, "wood").move(0, 0.8, 0))
    # наковальня
    m.add(rbox(1.5, 0.35, 0.9, 0.12, 1, "steelDark").move(-1.7, 3.25, 0.3))
    m.add(rbox(0.8, 0.4, 0.6, 0.12, 1, "steel").move(-1.7, 3.6, 0.3))
    m.add(rbox(1.9, 0.45, 1.0, 0.18, 1, "steel").move(-1.7, 4.0, 0.3))
    # молоток
    m.add(tube([(-0.3, 3.2, -0.6), (0.9, 3.6, -0.9)], 0.11, 6, color="wood"))
    m.add(rbox(0.5, 0.5, 0.95, 0.15, 1, "metalDark").rot("y", 15).move(1.0, 3.65, -0.9))
    # шестерёнка
    m.add(torus(0.6, 0.17, 12, 5, "gold").move(1.9, 3.2, 0.5))
    for x, y, z in ring_pos(8, 0.82, 3.2):
        m.add(sphere(0.17, 5, 3, "gold").move(1.9 + x, y, 0.5 + z))
    m.add(cyl(0.22, 0.3, 0.08, 8, "orange").move(1.9, 3.05, 0.5))
    # чертёж и кристалл
    m.add(rbox(1.7, 0.07, 1.2, 0.03, 1, "cream").rot("y", -12).move(0.3, 3.1, 0.6))
    m.add(crystal(0.3, 1.1, 6, 0.4, 0.3).move(2.5, 3.05, -0.95), glow="chrono")
    # тиски спереди
    m.add(rbox(0.9, 0.7, 0.5, 0.15, 1, "red").move(-2.2, 2.7, -1.6))
    return m


def beacon():
    m = Model()
    m.add(cyl(1.7, 0.9, 0.3, 14, "dark", r2=1.45)).grad("dark", "violet")
    m.add(cyl(1.15, 5.2, 0.25, 14, "cream", r2=0.85).move(0, 0.8, 0)).grad(mix(PAL["cream"], PAL["orange"], 0.3), "cream")
    m.add(torus(1.07, 0.2, 14, 6, "orange").move(0, 2.2, 0))
    m.add(torus(0.97, 0.2, 14, 6, "red").move(0, 4.2, 0))
    m.add(cyl(1.25, 0.4, 0.15, 14, "dark").move(0, 5.9, 0))
    m.add(cyl(0.85, 1.7, 0.2, 12).move(0, 6.25, 0), glow="gold")
    for x, y, z in ring_pos(4, 1.0, 0, math.pi / 4):
        m.add(tube([(x, 6.2, z), (x, 8.0, z)], 0.09, 4, color="dark"))
    m.add(lathe(fillet([(0, 7.9), (1.55, 7.9), (1.2, 8.4), (0.3, 9.5), (0, 9.6)], 0.2), 14, color="red")).grad("red", "pink")
    m.add(sphere(0.3, 8, 5, "gold").move(0, 9.75, 0))
    return m


def mine():
    m = Model()
    m.add(cyl(1.5, 0.3, 0.12, 12, "dark"))
    m.add(sphere(1.35, 14, 8, "steelDark").scale(1, 0.72, 1).move(0, 1.05, 0)).grad("dark", "steel")
    m.add(torus(1.33, 0.16, 14, 5, "orange").move(0, 1.05, 0))
    for x, y, z in ring_pos(8, 1.3, 1.05):
        a = -math.degrees(math.atan2(z, x))
        m.add(cone(0.24, 0.6, 5, "metal").rot("z", -90).rot("y", a).move(x, y, z))
    m.add(sphere(0.55, 10, 5).scale(1, 0.7, 1).move(0, 1.95, 0), glow="red")
    return m


def slow_field():
    m = Model()
    m.add(cyl(3.0, 0.3, 0.12, 20, "dark", r2=2.85)).grad("dark", "violet")
    m.add(torus(2.35, 0.14, 24, 5).move(0, 0.34, 0), glow="violet")
    m.add(torus(1.45, 0.12, 20, 5).move(0, 0.34, 0), glow="chrono")
    m.add(sphere(0.6, 10, 5).scale(1, 0.4, 1).move(0, 0.34, 0), glow="chrono")
    for x, y, z in ring_pos(4, 2.55, 0, math.pi / 4):
        m.add(cyl(0.3, 0.75, 0.1, 6, "gold", r2=0.2).move(x, 0.2, z))
        m.add(sphere(0.26, 6, 4).move(x, 1.1, z), glow="violet")
    # стрелки «часов» — намёк на замедление
    m.add(rbox(0.16, 0.08, 1.2, 0.04, 1, "cream").move(0, 0.36, -0.6))
    m.add(rbox(0.8, 0.08, 0.16, 0.04, 1, "cream").move(0.4, 0.36, 0))
    return m


def black_hole():
    m = Model()
    m.add(cyl(3.0, 0.35, 0.14, 20, "dark", r2=2.8)).grad("dark", "violet")
    m.add(torus(2.6, 0.12, 24, 5).move(0, 0.38, 0), glow="violet")
    m.add(sphere(1.45, 16, 9, "#120C1E").move(0, 2.6, 0))
    m.add(torus(2.35, 0.3, 28, 6, ry=0.1).rot("z", 18).rot("y", 20).move(0, 2.6, 0), glow="orange")
    m.add(torus(2.95, 0.14, 28, 5, ry=0.06).rot("z", -14).rot("y", -40).move(0, 2.6, 0), glow="violet")
    for i, (x, y, z) in enumerate(ring_pos(5, 2.2, 0, 0.9)):
        m.add(rbox(0.3, 0.3, 0.3, 0.1, 1, "cream").rot("y", i * 31).rot("x", i * 17).move(x * 0.9, 1.0 + 0.5 * i, z * 0.9))
    return m


# имя → (функция, бюджет треугольников, описание)
MODELS = {
    "pedestal": (lambda: pedestal("normal"), 2000, "Пьедестал артефакта"),
    "pedestalRich": (lambda: pedestal("rich"), 2000, "Пьедестал «богатый», золотой"),
    "islandBig": (lambda: island(90.0, 1, 7), 5000, "Парящий остров, большой"),
    "islandMid": (lambda: island(47.5, 4, 5), 5000, "Парящий остров, средний"),
    "wall1": (lambda: wall(1), 5000, "Стена ур. 1 — дерево"),
    "wall2": (lambda: wall(2), 5000, "Стена ур. 2 — камень"),
    "wall3": (lambda: wall(3), 5000, "Стена ур. 3 — металл"),
    "wall4": (lambda: wall(4), 5000, "Стена ур. 4 — укреплённая сталь"),
    "wall5": (lambda: wall(5), 5000, "Стена ур. 5 — хроно-барьер"),
    "gate1": (lambda: gate(1), 5000, "Ворота ур. 1"),
    "gate2": (lambda: gate(2), 5000, "Ворота ур. 2"),
    "gate3": (lambda: gate(3), 5000, "Ворота ур. 3"),
    "gate4": (lambda: gate(4), 5000, "Ворота ур. 4"),
    "gate5": (lambda: gate(5), 5000, "Ворота ур. 5 (энергетические)"),
    "bridge": (bridge, 5000, "Секция моста с перилами (вдоль Z)"),
    "crystalHub": (crystal_hub, 2000, "Центральный кристалл хаба"),
    "crystalA": (lambda: crystal_small("A"), 2000, "Кристалл-декор, одиночный"),
    "crystalB": (lambda: crystal_small("B"), 2000, "Кристалл-декор, тройка"),
    "crystalC": (lambda: crystal_small("C"), 2000, "Кристалл-декор, друза"),
    "tree": (tree, 2000, "Дерево"),
    "bush": (bush, 2000, "Куст с ягодами"),
    "lantern": (lantern, 2000, "Фонарь"),
    "crate": (crate, 2000, "Ящик"),
    "rock": (rock, 2000, "Камень"),
    "mushroom": (mushroom, 2000, "Гриб"),
    "conveyor": (conveyor, 2000, "Секция конвейера (лента вдоль +X, верх на 1.2)"),
    "portal": (portal, 2000, "Портал-арка артефактов"),
    "bench": (bench, 2000, "Верстак"),
    "beacon": (beacon, 2000, "Маяк базы"),
    "mine": (mine, 2000, "Ловушка: мина"),
    "slowField": (slow_field, 2000, "Ловушка: замедляющее поле"),
    "decoyPedestal": (lambda: pedestal("decoy"), 2000, "Ловушка: ложный пьедестал"),
    "blackHole": (black_hole, 2000, "Скин ловушки «Чёрная дыра»"),
}
