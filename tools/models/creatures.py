"""Существа-артефакты: 40 основных + 6 сезонных Титанов. Список читается из src/shared/Art/Defs.luau.

Каждое существо строится в «единичном» пространстве (рост ≈ 1, лицо смотрит на −Z) и масштабируется на размер
редкости (1 / 2 / 3 / 5 / 4 стада). Узлы по ролям, как в Art/Build.luau:
  Body, Head, Eye, Mouth, Limb, Prop — цвета в вершинах; Glow_RRGGBB — светящиеся кольца, осколки, ядра.
"""
import math
import os
import re

from meshlib import PAL, blob, cone, crystal, cyl, fillet, hexc, lathe, mix, rbox, sphere, torus, tube
from props import Model, ring_pos

HERE = os.path.dirname(os.path.abspath(__file__))
DEFS = os.path.join(os.path.dirname(os.path.dirname(HERE)), "src", "shared", "Art", "Defs.luau")
SIZE = {"common": 1, "rare": 2, "epic": 3, "legendary": 5, "chrono": 4}
INK = PAL["dark"]
WHITE = PAL["white"]
CREAM = PAL["cream"]


def dk(c, f=0.75):
    return mix(c, INK, 1 - f)


def lt(c, f=0.35):
    return mix(c, WHITE, f)


class C(Model):
    """Model с короткими помощниками и доступом к определению существа."""

    def __init__(self, d):
        super().__init__()
        self.d = d
        self.col = hexc(d["color"])
        self.glow = d["glow"]
        self.p = d["p"]

    def ball(self, r, pos, c=None, node="Body", s=(1, 1, 1), seg=12, rings=7):
        c = self.col if c is None else c
        return self.add(sphere(r, seg, rings, c).scale(*s).move(*pos), node=node)

    def g(self, mesh):
        return self.add(mesh, glow=self.glow)

    def face(self, center, w, n=2, emotion=None):
        """Глаза и рот на стороне −Z. center — центр лица, w — его ширина."""
        em = emotion or self.d["emotion"]
        cx, cy, cz = center
        ed = w * (0.2 if n > 2 else 0.27)
        for i in range(n):
            t = 0 if n == 1 else i / (n - 1) - 0.5
            x = cx + t * w * (0.95 if n > 2 else 0.62)
            y = cy + w * 0.12 - (abs(t) * 0.1 * w if n > 2 else 0)
            self.add(sphere(ed / 2, 8, 5, WHITE).scale(1, 1.08, 0.7).move(x, y, cz), node="Eye")
            self.add(sphere(ed * 0.27, 6, 4, INK).scale(1, 1, 0.6).move(x, y - ed * 0.03, cz - ed * 0.28), node="Eye")
            self.add(sphere(ed * 0.09, 4, 3, WHITE).move(x - ed * 0.1, y + ed * 0.1, cz - ed * 0.42), node="Eye")
            if em == "sleepy":
                self.add(sphere(ed * 0.53, 8, 4, dk(self.col, 0.85)).scale(1, 0.55, 0.75).move(x, y + ed * 0.22, cz - ed * 0.02), node="Eye")
            if em == "angry" or (em == "sly" and i == 0):
                tilt = (-24 if x < cx else 24) if em == "angry" else 16
                self.add(rbox(ed * 1.1, ed * 0.2, ed * 0.25, ed * 0.08, 1, INK).rot("z", tilt).move(x, y + ed * 0.62, cz - ed * 0.25), node="Eye")
        my = cy - w * 0.2
        mz = cz - w * 0.03
        if em == "surprise":
            self.add(sphere(w * 0.075, 6, 4, INK).scale(1, 1.2, 0.6).move(cx, my, mz), node="Mouth")
        elif em in ("smile", "sleepy"):
            pts = [(cx + w * 0.15 * math.sin(math.radians(a)), my + w * 0.07 - w * 0.09 * math.cos(math.radians(a)), mz) for a in (-70, -35, 0, 35, 70)]
            self.add(tube(pts, w * 0.028, 4, color=INK), node="Mouth")
        elif em == "angry":
            self.add(rbox(w * 0.3, w * 0.07, w * 0.06, w * 0.025, 1, INK).move(cx, my, mz), node="Mouth")
            for s in (-1, 1):
                self.add(cone(w * 0.035, w * 0.08, 4, WHITE).rot("x", 180).move(cx + s * w * 0.09, my + w * 0.02, mz - w * 0.02), node="Mouth")
        else:
            self.add(rbox(w * 0.26, w * 0.055, w * 0.06, w * 0.02, 1, INK).rot("z", 14).move(cx + w * 0.03, my, mz), node="Mouth")

    def legs(self, n, radius, y, ln, c, r=0.05):
        for i in range(n):
            a = (i + 0.5) / n * 2 * math.pi
            x, z = math.cos(a) * radius, math.sin(a) * radius
            self.add(tube([(x * 0.85, y + ln / 2, z * 0.85), (x * 1.1, y - ln / 2, z * 1.1)], r, 5, color=c), node="Limb")
            self.add(sphere(r * 1.5, 5, 3, c).move(x * 1.1, y - ln / 2, z * 1.1), node="Limb")

    def ring(self, R, y, tilt=0.0, r=0.03, tilt_z=0.0):
        self.g(torus(R, r, 20, 5).rot("x", tilt).rot("z", tilt_z).move(0, y, 0))

    def shards(self, n, R, y, s=0.12):
        for i in range(n):
            a = 2 * math.pi * i / n
            self.g(crystal(s * 0.5, s * 2.2, 4, 0.5, 0.5).rot("z", 25).rot("y", math.degrees(a)).move(R * math.cos(a), y + 0.1 * math.sin(2 * a) - s, R * math.sin(a)))


# ---------- семейства ----------
def s_drop(c):
    st = c.p.get("stretch", 1.2)
    prof = fillet([(0, -0.48), (0.3, -0.42), (0.4, -0.1), (0.22, 0.25), (0, 0.3 + 0.2 * st)], [0, 0.15, 0.2, 0.15, 0], 3)
    c.add(lathe(prof, 14, crease=75, color=c.col)).grad(dk(c.col, 0.85), lt(c.col))
    c.add(sphere(0.07, 6, 4, WHITE).scale(0.6, 1, 0.4).move(0.16, 0.12, -0.26))
    c.face((0, -0.12, -0.36), 0.5)


def s_stone(c):
    c.add(blob(0.44, 3, 0.12, 12, 7, c.col).scale(1.1, 0.82, 1).move(0, -0.1, 0)).grad(dk(c.col, 0.8), c.col)
    c.ball(0.2, (0.26, 0.18, 0.1), dk(c.col, 0.9), seg=8, rings=5)
    if c.p.get("moss"):
        c.add(blob(0.27, 4, 0.15, 8, 5, "grass").scale(1.2, 0.4, 1).move(-0.1, 0.25, 0.05), node="Prop")
        c.g(sphere(0.06, 6, 4).move(-0.15, 0.38, -0.05))
    c.face((0, -0.1, -0.41), 0.52)


def s_feather(c):
    c.ball(0.28, (0, -0.2, 0))
    for i in (-1, 0, 1):
        f = lathe(fillet([(0, 0), (0.09, 0.15), (0.1, 0.45), (0, 0.72)], 0.1), 6, crease=70, color=c.col).scale(1, 1, 0.35).rot("z", -i * 22).move(i * 0.13, 0.0, 0.1)
        if i == 0:
            c.g(f)
        else:
            c.add(f, node="Limb").grad(c.col, lt(c.col))
    c.face((0, -0.18, -0.27), 0.42)


def s_gem(c):
    n = c.p.get("facets", 6)
    c.add(lathe([(0, -0.5), (0.3, -0.2), (0.3, 0.2), (0, 0.5)], n, crease=20, color=c.col)).grad(dk(c.col, 0.85), lt(c.col))
    if c.p.get("spikes"):
        for i in range(4):
            a = math.pi / 4 + i * math.pi / 2
            c.g(cone(0.06, 0.26, 4).rot("z", -90).rot("y", -math.degrees(a)).move(0.3 * math.cos(a), 0.05, 0.3 * math.sin(a)))
    c.face((0, 0, -0.3), 0.44)


def s_blob(c):
    tall = 1.3 if c.p.get("tall") else 1.0
    prof = fillet([(0, -0.5), (0.42, -0.5), (0.48, -0.15), (0.36, 0.25 * tall), (0, 0.38 * tall)], [0, 0.12, 0.25, 0.25, 0], 3)
    c.add(lathe(prof, 14, crease=75, color=c.col)).grad(dk(c.col, 0.85), lt(c.col, 0.25))
    for i in range(c.p.get("bubbles", 0)):
        s = 1 if i == 0 else -1
        c.g(sphere(0.085, 8, 5).move(0.4 * s, 0.38 + 0.1 * i, 0))
    if c.p.get("frog"):
        for s in (-1, 1):
            c.ball(0.15, (s * 0.2, 0.36, -0.08), node="Head", seg=8, rings=5)
            c.add(sphere(0.085, 6, 4, WHITE).move(s * 0.2, 0.38, -0.19), node="Eye")
            c.add(sphere(0.04, 5, 3, INK).move(s * 0.2, 0.38, -0.265), node="Eye")
            c.ball(0.14, (s * 0.42, -0.45, -0.15), dk(c.col, 0.8), node="Limb", s=(1.4, 0.5, 1), seg=8, rings=5)
        c.g(torus(0.15, 0.025, 12, 4).rot("x", 90).move(0, -0.2, -0.47))
        c.face((0, 0.0, -0.46), 0.6, n=0)
        return
    c.face((0, -0.08 * tall, -0.45), 0.58)


def s_mush(c):
    c.add(lathe(fillet([(0, -0.5), (0.24, -0.5), (0.18, -0.2), (0.2, 0.05), (0, 0.05)], 0.08), 10, color=CREAM)).grad(mix(CREAM, PAL["orange"], 0.3), CREAM)
    cap = fillet([(0, -0.02), (0.36, -0.05), (0.48, 0.02), (0.4, 0.25), (0.2, 0.4), (0, 0.44)], [0, 0.05, 0.08, 0.15, 0.15, 0], 3)
    c.add(lathe(cap, 14, crease=75, color=c.col), node="Head").grad(dk(c.col, 0.8), lt(c.col, 0.2))
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.4
        c.g(sphere(0.07, 6, 4).scale(1, 0.5, 1).move(0.27 * math.cos(a), 0.32, 0.27 * math.sin(a)))
    c.face((0, -0.24, -0.2), 0.34)


def s_snail(c):
    c.add(lathe(fillet([(0, -0.5), (0.2, -0.5), (0.22, -0.36), (0, -0.28)], 0.06), 10, color=c.col).scale(2.3, 1, 1).move(0, 0, -0.08)).grad(dk(c.col, 0.85), c.col)
    sh = sphere(0.36, 14, 8, PAL["gold"]).scale(0.55, 1, 1).move(0.08, 0.0, 0.1)
    c.add(sh, node="Prop").grad("orange", "gold")
    for s in (-1, 1):
        c.g(torus(0.2, 0.035, 14, 4).rot("z", 90).move(0.08 + s * 0.2, 0.0, 0.1))
        c.add(tube([(-0.36, -0.3, s * 0.07 - 0.1), (-0.42, -0.05, s * 0.1 - 0.1)], 0.02, 4, color=c.col), node="Limb")
        c.g(sphere(0.045, 6, 4).move(-0.42, -0.02, s * 0.1 - 0.1))
    c.face((-0.3, -0.36, -0.29), 0.26)


def s_bug(c):
    crab = c.p.get("crab")
    c.ball(0.5, (0, -0.15, 0.15), s=(1, 0.7, 1.2))
    c.add(rbox(0.04, 0.3, 0.9, 0.015, 1, dk(c.col, 0.6)).move(0, 0.06, 0.2))
    c.ball(0.27, (0, -0.08, -0.45), dk(c.col, 0.8), node="Head", seg=10, rings=6)
    if c.p.get("horn"):
        c.add(cone(0.07, 0.36, 6, c.col).rot("x", -25).move(0, 0.12, -0.55), glow=c.glow)
    if crab:
        for s in (-1, 1):
            c.add(tube([(s * 0.35, -0.2, -0.2), (s * 0.58, -0.05, -0.4)], 0.05, 5, color=dk(c.col, 0.8)), node="Limb")
            c.ball(0.16, (s * 0.6, 0.02, -0.5), node="Limb", s=(1, 0.8, 1.3), seg=8, rings=5)
            c.add(cone(0.06, 0.16, 4, WHITE).rot("x", -90).move(s * 0.6, 0.05, -0.66), node="Limb")
        c.g(torus(0.2, 0.035, 10, 4).rot("x", 90).move(0, 0.2, 0.25))
        for i in range(6):
            a = math.pi * i / 3
            c.g(sphere(0.04, 4, 3).move(0.26 * math.cos(a), 0.2 + 0.26 * math.sin(a), 0.25))
    c.legs(6, 0.44, -0.4, 0.2, dk(c.col, 0.5), 0.035)
    c.face((0, -0.08, -0.7), 0.44)


def s_fox(c):
    big = 1.15 if c.p.get("big") else 1.0
    c.ball(0.4 * big, (0, -0.22, 0.12), s=(0.9, 0.8, 1.2))
    c.ball(0.22 * big, (0, -0.28, -0.12), CREAM, s=(0.8, 0.75, 0.6), seg=8, rings=5)
    c.ball(0.31 * big, (0, 0.2, -0.2), node="Head")
    c.add(cone(0.13, 0.26, 8, WHITE, bevel=0.04).rot("x", -90).move(0, 0.1, -0.42), node="Head")
    c.add(sphere(0.045, 5, 3, INK).move(0, 0.12, -0.69), node="Head")
    for s in (-1, 1):
        c.add(cone(0.11, 0.3, 6, c.col, bevel=0.03).scale(1, 1, 0.6).rot("z", -s * 14).move(s * 0.2, 0.4, -0.18), node="Head")
        c.g(cone(0.055, 0.17, 4).scale(1, 1, 0.5).rot("z", -s * 14).move(s * 0.2, 0.43, -0.23))
        c.add(tube([(s * 0.18, -0.4, -0.08), (s * 0.18, -0.52, -0.1)], 0.07, 6, color=dk(c.col, 0.7)), node="Limb")
    n = c.p.get("tails", 1)
    for i in range(n):
        a = (i - (n - 1) / 2) * 0.6
        pts = [(math.sin(a) * 0.1, -0.2, 0.5), (math.sin(a) * 0.3, 0.05, 0.75), (math.sin(a) * 0.42, 0.35, 0.82)]
        c.add(tube(pts, [0.09, 0.14, 0.05], 6, color=c.col), node="Limb").grad(c.col, WHITE)
        c.g(sphere(0.06, 5, 3).move(*pts[-1]))
    c.face((0, 0.2, -0.47), 0.46)


def s_owl(c):
    prof = fillet([(0, -0.5), (0.36, -0.5), (0.47, -0.1), (0.4, 0.3), (0, 0.5)], [0, 0.12, 0.25, 0.25, 0], 3)
    c.add(lathe(prof, 14, crease=75, color=c.col).scale(1, 1, 0.9)).grad(dk(c.col, 0.8), c.col)
    c.ball(0.3, (0, -0.22, -0.2), CREAM, s=(1, 1, 0.6), seg=10, rings=6)
    for s in (-1, 1):
        c.add(sphere(0.3, 8, 5, dk(c.col, 0.8)).scale(0.35, 1, 0.75).rot("z", s * 12).move(s * 0.46, -0.12, 0.03), node="Limb")
        if c.p.get("ears"):
            c.g(cone(0.08, 0.26, 4).rot("z", -s * 15).move(s * 0.24, 0.36, 0))
        if c.p.get("bell"):
            c.add(sphere(0.13, 8, 5, PAL["gold"]).move(s * 0.26, 0.48, 0), node="Head")
        c.add(sphere(0.07, 5, 3, PAL["orange"]).scale(1.3, 0.5, 1.3).move(s * 0.16, -0.5, -0.12), node="Limb")
    if c.p.get("bell"):
        c.add(tube([(-0.26, 0.6, 0), (0, 0.68, 0), (0.26, 0.6, 0)], 0.025, 4, color=dk(PAL["gold"], 0.7)), node="Head")
    c.add(cone(0.06, 0.12, 4, PAL["orange"]).rot("x", 180).move(0, 0.1, -0.44), node="Head")
    c.face((0, 0.14, -0.39), 0.6)


def s_bat(c):
    moth = c.p.get("moth")
    c.ball(0.33, (0, 0, 0), s=(1, 1.1, 0.9))
    for s in (-1, 1):
        if moth:
            for y, r in ((0.16, 0.3), (-0.16, 0.22)):
                c.g(sphere(r, 10, 5).scale(1, 0.85, 0.1).rot("z", -s * 15).move(s * 0.5, y, 0.06))
            c.add(tube([(s * 0.08, 0.3, -0.05), (s * 0.2, 0.5, -0.12)], 0.018, 4, color=dk(c.col, 0.6)), node="Head")
            c.g(sphere(0.04, 5, 3).move(s * 0.2, 0.52, -0.12))
        else:
            wing = lathe([(0, 0), (0.38, 0.05), (0.3, 0.3), (0, 0.42)], 8, crease=70, color=dk(c.col, 0.8)).scale(1, 1, 0.12).rot("z", -s * 70).move(s * 0.22, -0.02, 0.06)
            c.add(wing, node="Limb").grad(dk(c.col, 0.7), c.glow)
            c.add(cone(0.08, 0.24, 4, c.col).rot("z", -s * 10).move(s * 0.17, 0.28, 0), node="Head")
    c.face((0, 0.04, -0.29), 0.46)


def s_golem(c):
    col = c.col
    if c.p.get("shell"):
        dome = lathe(fillet([(0, -0.36), (0.58, -0.36), (0.56, -0.1), (0.3, 0.22), (0, 0.28)], [0, 0.08, 0.2, 0.2, 0], 3), 14, crease=75, color=col)
        c.add(dome.move(0, 0, 0.1)).grad(dk(col, 0.75), col)
        for i in range(6):
            a = math.pi * i / 3
            c.g(sphere(0.07, 6, 4).scale(1, 0.4, 1).move(0.33 * math.cos(a), 0.12, 0.33 * math.sin(a) + 0.1))
        c.g(sphere(0.09, 6, 4).scale(1, 0.4, 1).move(0, 0.28, 0.1))
        c.ball(0.22, (0, -0.15, -0.58), hexc("#8BC34A"), node="Head", seg=10, rings=6)
        c.face((0, -0.14, -0.77), 0.34)
        c.legs(4, 0.46, -0.42, 0.16, hexc("#6FA53A"), 0.07)
        return
    k = 0.85 if c.p.get("small") else 1.0
    c.add(rbox(0.75 * k, 0.6 * k, 0.55 * k, 0.14, 2, col).move(0, -0.13, 0)).grad(dk(col, 0.8), col)
    c.add(rbox(0.52 * k, 0.42 * k, 0.46 * k, 0.12, 2, dk(col, 0.92)).move(0, 0.36 * k, -0.04), node="Head")
    for s in (-1, 1):
        c.add(rbox(0.22 * k, 0.55 * k, 0.22 * k, 0.08, 1, dk(col, 0.8)).rot("z", s * 9).move(s * 0.52 * k, -0.13, 0), node="Limb")
        c.add(rbox(0.24 * k, 0.26, 0.27 * k, 0.08, 1, dk(col, 0.7)).move(s * 0.2 * k, -0.52, 0), node="Limb")
        if c.p.get("claws"):
            for j in (-1, 0, 1):
                c.add(cone(0.035, 0.14, 4, WHITE).rot("x", 200).move(s * 0.55 * k + j * 0.07, -0.4, -0.06), node="Limb")
    c.g(sphere(0.11, 8, 4).scale(1, 1, 0.4).move(0, -0.1, -0.28 * k))
    if c.p.get("cogs"):
        c.ring(0.6, 0.02, tilt=17, r=0.035)
        for i in range(8):
            a = math.pi * i / 4
            c.g(sphere(0.05, 4, 3).move(0.6 * math.cos(a), 0.02 + 0.18 * math.sin(a), 0.57 * math.sin(a)))
        c.add(torus(0.13, 0.04, 8, 4, PAL["gold"]).rot("z", 90).move(0.31 * k, 0.5 * k, 0), node="Prop")
    c.face((0, 0.37 * k, -0.28 * k), 0.4)


def s_dragon(c):
    ph = c.p.get("phoenix")
    col = c.col
    c.ball(0.36, (0, -0.2, 0.1), s=(1, 0.9, 1.25))
    c.ball(0.2, (0, -0.28, -0.12), lt(col, 0.5), s=(0.85, 0.75, 0.6), seg=8, rings=5)
    c.ball(0.27, (0, 0.2, -0.22), node="Head")
    c.ball(0.15, (0, 0.12, -0.45), lt(col, 0.2), node="Head", s=(1, 0.75, 1), seg=8, rings=5)
    for s in (-1, 1):
        c.add(cone(0.05, 0.22, 5, CREAM if not ph else PAL["gold"]).rot("x", 25).rot("z", -s * 20).move(s * 0.14, 0.4, -0.12), node="Head")
        wing = lathe([(0, 0), (0.44, 0.1), (0.36, 0.4), (0, 0.5)], 8, crease=70, color=col).scale(1, 1, 0.1).rot("z", -s * 60).rot("y", -s * 15).move(s * 0.25, -0.05, 0.2)
        if ph:
            c.g(wing)
        else:
            c.add(wing, node="Limb").grad(dk(col, 0.7), c.glow)
        c.add(sphere(0.09, 6, 4, dk(col, 0.7)).scale(1, 0.7, 1.3).move(s * 0.2, -0.5, -0.02), node="Limb")
    tail = [(0, -0.3, 0.45), (0.1, -0.35, 0.72), (0.28, -0.25, 0.85)]
    c.add(tube(tail, [0.12, 0.08, 0.04], 6, color=col), node="Limb")
    c.g(crystal(0.07, 0.2, 4, 0.5, 0.5).rot("z", -60).move(0.3, -0.24, 0.86))
    for i in range(3):
        c.g(cone(0.05, 0.14, 4).move(0, 0.12 - 0.13 * i, 0.26 + 0.1 * i))
    if ph:
        for dx in (-0.08, 0, 0.08):
            c.g(lathe(fillet([(0, 0), (0.05, 0.1), (0, 0.32)], 0.04), 5, crease=70).rot("x", 20).move(dx, 0.42, -0.2))
    c.face((0, 0.24, -0.47), 0.4)


def s_hourglass(c):
    col = c.col
    for y in (-0.47, 0.44):
        c.add(cyl(0.34, 0.08, 0.03, 12, PAL["gold"]).move(0, y, 0), node="Prop")
    glass = lathe(fillet([(0, -0.42), (0.28, -0.42), (0.26, -0.2), (0.07, 0.0), (0.26, 0.2), (0.28, 0.42), (0, 0.42)], [0, 0.04, 0.12, 0.05, 0.12, 0.04, 0], 3), 14, crease=75, color=lt(col, 0.5))
    c.add(glass).grad(lt(col, 0.3), lt(col, 0.7))
    c.g(cone(0.2, 0.2, 10).move(0, -0.4, 0.0))
    c.g(sphere(0.1, 8, 4).scale(1.6, 0.5, 1.6).move(0, 0.3, 0))
    for x, y, z in ring_pos(3, 0.3, 0):
        c.add(tube([(x, -0.42, z + 0.0), (x, 0.44, z)], 0.025, 4, color=dk(PAL["gold"], 0.8)), node="Prop")
    c.ring(0.5, 0.0, tilt=20)
    c.face((0, 0.22, -0.25), 0.36)


def s_knight(c):
    col = c.col
    prof = fillet([(0, -0.5), (0.3, -0.5), (0.36, -0.2), (0.3, 0.1), (0, 0.14)], [0, 0.08, 0.15, 0.1, 0], 3)
    c.add(lathe(prof, 12, crease=75, color=col)).grad(dk(col, 0.75), col)
    c.add(torus(0.34, 0.04, 12, 4, PAL["gold"]).move(0, -0.2, 0))
    helm = lathe(fillet([(0, 0.08), (0.27, 0.08), (0.29, 0.3), (0.16, 0.48), (0, 0.5)], [0, 0.05, 0.12, 0.1, 0], 3), 12, crease=75, color=lt(col, 0.15))
    c.add(helm, node="Head")
    c.add(rbox(0.36, 0.1, 0.1, 0.04, 1, INK).move(0, 0.27, -0.25), node="Head")
    for s in (-1, 1):
        c.g(sphere(0.035, 5, 3).move(s * 0.08, 0.27, -0.3))
        c.ball(0.13, (s * 0.38, 0.02, 0), lt(col, 0.2), node="Limb", seg=8, rings=5)
        c.add(tube([(s * 0.4, -0.02, 0), (s * 0.44, -0.3, -0.05)], 0.07, 5, color=dk(col, 0.8)), node="Limb")
    c.g(lathe(fillet([(0, 0.48), (0.05, 0.56), (0, 0.78)], 0.04), 5, crease=70).rot("x", 20))
    sh = lathe(fillet([(0, -0.22), (0.2, -0.05), (0.2, 0.18), (0, 0.2)], 0.05), 6, crease=40, color=lt(col, 0.3)).scale(1, 1, 0.25).move(-0.44, -0.25, -0.2)
    c.add(sh, node="Prop")
    c.g(sphere(0.06, 6, 4).scale(1, 1, 0.5).move(-0.44, -0.22, -0.26))
    c.add(tube([(0.46, -0.42, -0.12), (0.46, 0.3, -0.12)], 0.025, 4, color=CREAM), node="Prop")
    c.add(rbox(0.16, 0.04, 0.05, 0.015, 1, PAL["gold"]).move(0.46, -0.22, -0.12), node="Prop")


def s_serpent(c):
    col = c.col
    pts, rs = [], []
    n = 22
    for i in range(n):
        t = i / (n - 1)
        a = t * 2 * math.pi * 2.2
        R = 0.42 - 0.2 * t
        pts.append((R * math.cos(a), -0.42 + 0.75 * t, R * math.sin(a)))
        rs.append(0.06 + 0.07 * math.sin(math.pi * min(1, t * 1.4 + 0.15)))
    body = tube(pts, rs, 7, color=col)
    c.add(body.paint_fn(lambda p: mix(dk(col, 0.75), lt(col, 0.2), (p[1] + 0.45) / 0.9)))
    hx, hy, hz = pts[-1]
    c.ball(0.19, (0, hy + 0.1, -0.12), node="Head", s=(1, 0.85, 1.25), seg=10, rings=6)
    c.g(crystal(0.05, 0.16, 4, 0.5, 0.5).move(0, hy + 0.22, -0.08))
    c.g(torus(0.5, 0.025, 16, 4).move(0, -0.47, 0))
    for i in range(12):
        a = 2 * math.pi * i / 12
        c.g(sphere(0.03, 4, 3).move(0.5 * math.cos(a), -0.47, 0.5 * math.sin(a)))
    c.add(tube([(0, hy + 0.04, -0.34), (0, hy + 0.0, -0.44)], 0.012, 3, color=PAL["red"]), node="Mouth")
    c.face((0, hy + 0.12, -0.31), 0.3)


THEMES = {
    "pumpkin": "s1", "ice": "s2", "sand": "s3", "sakura": "s4", "space": "s5", "coral": "s6",
}


def s_titan(c):
    col = c.col
    owl = c.p.get("owl")
    theme = c.p.get("theme")
    torso = lathe(fillet([(0, -0.5), (0.2, -0.5), (0.26, -0.3), (0.42, 0.05), (0.3, 0.2), (0, 0.22)], [0, 0.05, 0.1, 0.12, 0.08, 0], 3), 12, crease=75, color=col)
    c.add(torso.scale(1, 1, 0.75)).grad(dk(col, 0.7), col)
    c.g(sphere(0.1, 8, 5).scale(1, 1, 0.5).move(0, -0.02, -0.27))
    c.add(torus(0.12, 0.03, 10, 4, PAL["gold"]).rot("x", 90).move(0, -0.02, -0.28), node="Prop")
    c.ball(0.2, (0, 0.34, -0.03), lt(col, 0.1), node="Head", s=(1, 0.95, 0.95), seg=10, rings=6)
    for s in (-1, 1):
        c.ball(0.16, (s * 0.45, 0.12, 0), lt(col, 0.2), node="Limb", s=(1, 0.8, 1), seg=8, rings=5)
        c.add(tube([(s * 0.47, 0.05, 0), (s * 0.55, -0.2, -0.04), (s * 0.5, -0.4, -0.1)], [0.09, 0.1, 0.12], 6, color=dk(col, 0.85)), node="Limb")
        c.add(tube([(s * 0.13, -0.28, 0), (s * 0.15, -0.5, 0)], 0.1, 6, color=dk(col, 0.75)), node="Limb")
        if owl:
            c.g(cone(0.06, 0.2, 4).rot("z", -s * 20).move(s * 0.14, 0.46, 0))
        elif not theme:
            c.add(cone(0.05, 0.2, 5, PAL["gold"]).rot("z", -s * 35).move(s * 0.16, 0.44, 0), node="Head")
    if owl:
        c.add(cone(0.045, 0.1, 4, PAL["orange"]).rot("x", 180).move(0, 0.34, -0.21), node="Head")
        c.add(torus(0.13, 0.03, 10, 4, PAL["gold"]).move(0, 0.55, 0), node="Prop")
        for i in range(5):
            a = 2 * math.pi * i / 5
            c.add(cone(0.03, 0.09, 4, PAL["gold"]).move(0.13 * math.cos(a), 0.56, 0.13 * math.sin(a)), node="Prop")
    c.ring(0.66, -0.12, tilt=10, r=0.025)
    c.shards(5, 0.66, -0.12, 0.07)
    # тема сезона — простой венец на голове
    if theme == "pumpkin":
        c.add(tube([(0, 0.52, 0), (0.03, 0.62, 0), (0.1, 0.66, 0)], 0.035, 5, color=PAL["grassDark"]), node="Prop")
        c.add(blob(0.12, 5, 0.15, 6, 4, "grass").scale(1, 0.25, 0.7).move(-0.08, 0.54, 0), node="Prop")
    elif theme == "ice":
        for dx, h in ((-0.1, 0.16), (0, 0.24), (0.1, 0.16)):
            c.g(crystal(0.045, h, 6, 0.4, 0.2).move(dx, 0.5, 0))
    elif theme == "sand":
        c.add(cyl(0.2, 0.05, 0.02, 10, PAL["gold"], steps=1).move(0, 0.5, 0), node="Prop")
        c.add(cone(0.14, 0.16, 4, PAL["gold"]).move(0, 0.54, 0), node="Prop")
    elif theme == "sakura":
        for i in range(5):
            a = 2 * math.pi * i / 5
            c.add(sphere(0.06, 6, 4, WHITE).scale(1, 0.4, 1).move(0.07 * math.cos(a) + 0.08, 0.54, 0.07 * math.sin(a)), node="Prop")
        c.add(sphere(0.04, 5, 3, PAL["gold"]).move(0.08, 0.56, 0), node="Prop")
    elif theme == "space":
        c.g(torus(0.26, 0.02, 16, 4).rot("x", 20).move(0, 0.36, -0.03))
        c.add(sphere(0.045, 5, 3, CREAM).move(0.26, 0.4, -0.05), node="Prop")
    elif theme == "coral":
        for dx, h, l in ((-0.08, 0.18, -0.05), (0.02, 0.24, 0.03), (0.1, 0.15, 0.06)):
            c.add(tube([(dx, 0.5, 0), (dx + l, 0.5 + h, 0)], [0.035, 0.025], 5, color=PAL["pink"]), node="Prop")
            c.add(sphere(0.035, 5, 3, lt(PAL["pink"])).move(dx + l, 0.5 + h, 0), node="Prop")
    c.face((0, 0.33, -0.2), 0.34, n=3 if not owl else 2)


def s_eater(c):
    col = c.col
    c.add(blob(0.45, 9, 0.06, 14, 8, col).scale(1.05, 0.95, 1).move(0, -0.02, 0)).grad(dk(col, 0.65), lt(col, 0.15))
    c.add(sphere(0.3, 12, 6, INK).scale(1, 0.62, 0.4).move(0, -0.12, -0.33), node="Mouth")
    for i in range(5):
        x = -0.2 + 0.1 * i
        c.add(cone(0.04, 0.11, 4, WHITE).rot("x", 180).move(x, 0.02 - 0.012 * (i - 2) ** 2, -0.42), node="Mouth")
        if 0 < i < 4:
            c.add(cone(0.035, 0.09, 4, WHITE).move(x, -0.3 + 0.01 * (i - 2) ** 2, -0.4), node="Mouth")
    c.g(sphere(0.1, 8, 5).scale(1, 0.6, 0.5).move(0, -0.14, -0.36))
    if c.p.get("tentacles"):
        for i in range(6):
            a = math.pi * (0.1 + 0.8 * i / 5) + math.pi
            x, z = 0.36 * math.cos(a), 0.28 * math.sin(a) + 0.05
            pts = [(x, -0.3, z), (x * 1.35, -0.45, z * 1.2), (x * 1.6, -0.36, z * 1.3 - 0.08)]
            c.add(tube(pts, [0.08, 0.06, 0.03], 5, color=dk(col, 0.85)), node="Limb")
            c.g(sphere(0.035, 4, 3).move(*pts[-1]))
        c.ball(0.22, (0, 0.3, 0.05), lt(col, 0.1), node="Head", s=(1.2, 0.8, 1.1), seg=10, rings=6)
    else:
        for s in (-1, 1):
            c.add(cone(0.08, 0.26, 5, dk(col, 0.6)).rot("z", -s * 35).move(s * 0.28, 0.3, 0), node="Head")
            c.add(tube([(s * 0.42, -0.1, 0), (s * 0.58, -0.25, -0.1)], [0.08, 0.05], 5, color=dk(col, 0.8)), node="Limb")
        c.legs(4, 0.3, -0.45, 0.12, dk(col, 0.6), 0.06)
    c.ring(0.6, 0.12, tilt=-14, r=0.025)
    c.face((0, 0.22, -0.4), 0.5, n=3, emotion="blank")


def s_colossus(c):
    col = c.col
    if c.p.get("whale"):
        body = lathe(fillet([(0, -0.55), (0.3, -0.4), (0.36, -0.05), (0.22, 0.35), (0.06, 0.6), (0, 0.62)], [0, 0.12, 0.2, 0.15, 0.03, 0], 3), 14, crease=75, color=col)
        body.rot("x", -90)  # вытянут вдоль Z, нос на −Z
        c.add(body.paint_fn(lambda p: mix(lt(col, 0.6), col, min(1, max(0, (p[1] + 0.12) / 0.2)))))
        for s in (-1, 1):
            c.add(sphere(0.2, 8, 5, dk(col, 0.85)).scale(1, 0.18, 0.55).rot("z", -s * 20).move(s * 0.42, -0.12, -0.1), node="Limb")
            c.add(sphere(0.17, 8, 5, dk(col, 0.85)).scale(1, 0.18, 0.6).rot("y", s * 30).move(s * 0.15, 0.03, 0.7), node="Limb")
        c.g(lathe(fillet([(0, 0), (0.04, 0.05), (0.1, 0.22), (0, 0.2)], 0.03), 6, crease=70).move(0, 0.34, -0.1))
        for i in range(3):
            c.g(sphere(0.035 - 0.006 * i, 5, 3).move(0.08 * (i - 1), 0.62 + 0.03 * (i % 2), -0.1))
        c.ring(0.62, 0.0, tilt=10, r=0.02)
        c.face((0, -0.02, -0.5), 0.36)
        return
    c.add(rbox(0.5, 0.34, 0.4, 0.1, 2, dk(col, 0.8)).move(0, -0.33, 0)).grad(dk(col, 0.65), dk(col, 0.9))
    c.add(rbox(0.66, 0.36, 0.46, 0.12, 2, col).move(0, 0.0, 0)).grad(dk(col, 0.9), col)
    c.add(rbox(0.4, 0.3, 0.36, 0.1, 2, lt(col, 0.15)).move(0, 0.32, -0.02), node="Head")
    for s in (-1, 1):
        c.add(rbox(0.2, 0.5, 0.22, 0.08, 1, dk(col, 0.85)).rot("z", s * 8).move(s * 0.45, -0.1, 0), node="Limb")
        c.ball(0.11, (s * 0.48, -0.38, 0), lt(col, 0.2), node="Limb", seg=8, rings=5)
    c.g(sphere(0.12, 10, 5).scale(1, 1, 0.4).move(0, 0.0, -0.23))
    # солнечный венец за головой
    c.g(torus(0.3, 0.03, 16, 4).rot("x", 90).move(0, 0.36, 0.12))
    for i in range(8):
        a = math.pi * i / 4
        c.g(cone(0.035, 0.12, 4).rot("z", math.degrees(a) - 90).move(0.36 * math.cos(a), 0.36 + 0.36 * math.sin(a), 0.12))
    c.face((0, 0.32, -0.2), 0.34)


def s_rift(c):
    col = c.col
    c.g(sphere(0.2, 10, 6).scale(0.8, 1.5, 0.8))
    spec = ((0.3, 0.62, -18, 0, 0.26, -0.1), (0.26, 0.5, 20, 10, -0.27, 0.0), (0.2, 0.4, -8, -25, 0.05, 0.18), (0.16, 0.36, 28, 20, -0.1, -0.28))
    for i, (r, h, tz, tx, x, y) in enumerate(spec):
        m = lathe([(0, -h / 2), (r * 0.5, -h * 0.15), (r * 0.42, h * 0.2), (0, h / 2)], 5, crease=20, color=dk(col, 0.55)).scale(1, 1, 0.55)
        c.add(m.rot("x", tx).rot("z", tz).move(x, y, 0.06 * (i % 2))).grad(INK, mix(INK, col, 0.6))
    c.shards(6, 0.5, 0.05, 0.09)
    if c.p.get("ring"):
        c.ring(0.56, 0.0, tilt=75, r=0.025)
        c.ring(0.46, 0.0, tilt=75, r=0.018, tilt_z=50)
    c.face((0, 0.02, -0.19), 0.32)


def s_paradox(c):
    col, g2 = c.col, hexc(c.glow)
    for s, cc in ((-1, col), (1, g2)):
        prof = fillet([(0, -0.45), (0.2, -0.45), (0.25, -0.15), (0.18, 0.2), (0, 0.3)], [0, 0.06, 0.12, 0.1, 0], 3)
        b = lathe(prof, 10, crease=75, color=cc).move(s * 0.23, 0, 0)
        if s < 0:
            c.add(b).grad(dk(cc, 0.75), lt(cc, 0.2))
        else:
            c.g(b)
        for k in (-1, 1):
            c.add(cone(0.045, 0.16, 4, dk(cc, 0.6)).rot("z", -k * 25).move(s * 0.23 + k * 0.1, 0.26, 0), node="Head")
    c.add(torus(0.12, 0.03, 10, 4, PAL["gold"]).rot("z", 90).move(0, -0.1, 0), node="Prop")
    if c.p.get("shield"):
        c.g(sphere(0.34, 12, 5).scale(1, 1.15, 0.08).move(0, -0.08, -0.34))
        c.add(torus(0.34, 0.035, 14, 4, PAL["gold"]).scale(1, 1.15, 1).rot("x", 90).move(0, -0.08, -0.34), node="Prop")
    c.ring(0.55, -0.42, r=0.02)
    for s in (-1, 1):
        # у каждого двойника свой глаз и общий на двоих характер
        x = s * 0.23
        c.add(sphere(0.07, 8, 5, WHITE).scale(1, 1.1, 0.7).move(x, 0.02, -0.22), node="Eye")
        c.add(sphere(0.038, 6, 4, INK).scale(1, 1, 0.6).move(x, 0.015, -0.265), node="Eye")
        c.add(rbox(0.14, 0.03, 0.04, 0.012, 1, INK).rot("z", -s * 18).move(x, 0.11, -0.26), node="Eye")
        c.add(rbox(0.1, 0.025, 0.03, 0.01, 1, INK).rot("z", s * 12).move(x, -0.12, -0.245), node="Mouth")


def s_zero(c):
    col = c.col
    loop = c.p.get("loop")
    if loop:
        # петля: два сцепленных кольца
        c.add(torus(0.3, 0.085, 20, 7, col).rot("x", 90).rot("y", 25).move(-0.17, 0, 0)).grad(dk(col, 0.8), lt(col, 0.2), axis=1)
        c.g(torus(0.3, 0.07, 20, 6).rot("x", 90).rot("y", -25).move(0.17, 0, 0))
        c.ball(0.15, (-0.17, 0, -0.05), lt(col, 0.3), node="Head", seg=10, rings=6)
        c.face((-0.17, 0.0, -0.17), 0.26)
    else:
        c.add(torus(0.36, 0.1, 24, 8, col).scale(0.85, 1, 1).rot("x", 90)).grad(dk(col, 0.85), col, axis=1)
        c.g(torus(0.36, 0.035, 24, 4).scale(0.85, 1, 1).rot("x", 90).move(0, 0, -0.09))
        c.ball(0.16, (0, 0, 0), INK, node="Head", seg=10, rings=6)
        c.face((0, 0.0, -0.13), 0.28)
    c.shards(5, 0.56, 0.0, 0.08)
    c.ring(0.56, -0.44, r=0.02)


SHAPES = {
    "drop": s_drop, "stone": s_stone, "feather": s_feather, "gem": s_gem, "mush": s_mush, "blob": s_blob, "bug": s_bug,
    "fox": s_fox, "owl": s_owl, "bat": s_bat, "golem": s_golem, "snail": s_snail, "dragon": s_dragon,
    "hourglass": s_hourglass, "knight": s_knight, "serpent": s_serpent, "titan": s_titan, "eater": s_eater,
    "colossus": s_colossus, "rift": s_rift, "paradox": s_paradox, "zero": s_zero,
}


# ---------- чтение Defs.luau ----------
def _params(s):
    p = {}
    for k, v in re.findall(r"(\w+)\s*=\s*([\w.\"]+)", s):
        if v in ("true", "false"):
            p[k] = v == "true"
        else:
            try:
                p[k] = float(v) if "." in v else int(v)
            except ValueError:
                p[k] = v.strip('"')
    return p


def load_defs():
    src = open(DEFS, encoding="utf-8").read()
    out = []
    pat = r'def\("(\w+)",\s*"([^"]*)",\s*"([^"]*)",\s*"(\w+)",\s*[\d.]+,\s*"(#\w+)",\s*"(#\w+)",\s*"(\w+)",\s*"(\w+)",\s*\{([^}]*)\}'
    for m in re.finditer(pat, src):
        i, ru, en, rar, col, glow, shape, emo, ps = m.groups()
        out.append({"id": i, "ru": ru, "rarity": rar, "color": col, "glow": glow, "shape": shape, "emotion": emo, "p": _params(ps)})
    for n, m in enumerate(re.finditer(r'\{\s*"([^"]+)",\s*"[^"]+",\s*"(#\w+)",\s*"(#\w+)",\s*"(\w+)"\s*\}', src), 1):
        ru, col, glow, theme = m.groups()
        out.append({"id": f"s{n}", "ru": ru, "rarity": "legendary", "color": col, "glow": glow, "shape": "titan", "emotion": "smile", "p": {"theme": theme}})
    return out


def creature(d):
    c = C(d)
    orig = c.face

    def face(center, w, n=2, emotion=None):
        if n:
            orig(center, w, n, emotion if emotion != "blank" else None)
    c.face = face
    SHAPES[d["shape"]](c)
    return c.scale(SIZE[d["rarity"]])


MODELS = {}
for _d in load_defs():
    # имя модели: art_<id> — чтобы не пересекаться с декором сезонов (s1Pumpkin и т. п.)
    MODELS["art_" + _d["id"]] = ((lambda d=_d: creature(d)), 2000, f"Существо «{_d['ru']}» ({_d['rarity']}, {_d['shape']})")
