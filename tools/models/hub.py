"""Модели второй очереди: хаб (сундук, кольцевой конвейер, порталы, подиумы), базы (кнопка замка, плита,
второй этаж), сезонный остров (алтарь, клетка, декор шести сезонов), дубинка.

Без символов и знаков: только простые формы (кружки, кольца, кристаллы).
"""
import math

from meshlib import (PAL, arc, arc_prism, blob, cone, crystal, cyl, fillet, lathe, mix, prism, rbox, sphere, torus,
                     tube)
from props import Model, portal, ring_pos, tree

# ================= ХАБ =================
CHEST_W, CHEST_D, CHEST_H = 10.0, 7.0, 3.5  # корпус; крышка сверху ещё ~2.6


def chest():
    """Корпус золотого сундука с горкой монет и самоцветов. Крышка — отдельная модель chestLid."""
    m = Model()
    W, D, H = CHEST_W, CHEST_D, CHEST_H
    m.add(rbox(W - 0.4, H, D - 0.4, 0.5, 2, "gold").move(0, H / 2, 0)).grad(mix(PAL["orange"], PAL["gold"], 0.4), "gold")
    m.add(rbox(W, 0.7, D, 0.3, 1, "dark").move(0, 0.35, 0))
    m.add(rbox(W, 0.6, D, 0.25, 1, "orange").move(0, H - 0.3, 0))
    for x in (-W / 2 + 0.55, 0.0, W / 2 - 0.55):
        m.add(rbox(1.0, H + 0.1, D + 0.1, 0.3, 1, "orange" if x else "red").move(x, H / 2, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.add(sphere(0.5, 8, 5, "cream").move(sx * (W / 2 - 0.3), 0.5, sz * (D / 2 - 0.3)))
    # замок спереди
    m.add(rbox(1.7, 1.9, 0.5, 0.35, 2, "cream").move(0, H - 0.9, -D / 2 - 0.1))
    m.add(sphere(0.38, 8, 5).scale(1, 1, 0.5).move(0, H - 0.8, -D / 2 - 0.36), glow="chrono")
    # сокровища
    heap = blob(1.0, 41, 0.1, 14, 7, "gold").scale(W / 2 - 0.9, 1.5, D / 2 - 0.9).move(0, H - 0.1, 0)
    m.add(heap.grad("orange", mix(PAL["gold"], PAL["white"], 0.3)))
    k = 0
    for x, z in ((-2.6, -1.0), (-1.2, 1.2), (0.6, -1.5), (2.2, 0.8), (3.0, -0.9), (-3.2, 0.9), (0.2, 0.6), (1.5, -0.3), (-1.6, -0.4)):
        k += 1
        y = H + 1.25 - 0.045 * (x * x + 2 * z * z)
        m.add(cyl(0.55, 0.16, 0.06, 10, "gold", steps=1).rot("x", 25 * math.sin(k * 2.1)).rot("z", 30 * math.cos(k * 1.3)).move(x, y, z))
    for i, (x, z, c) in enumerate(((-2.0, 0.4, "red"), (1.0, 1.1, "chrono"), (2.6, -0.2, "violet"), (-0.6, -1.3, "chrono"), (-3.4, -0.7, "violet"))):
        y = H + 1.15 - 0.045 * (x * x + 2 * z * z)
        m.add(crystal(0.42, 1.0, 6, 0.45, 0.4).rot("z", 20 * math.sin(i * 3.0)).rot("x", 15 * math.cos(i * 2.0)).move(x, y, z), glow=c)
    return m


def chest_lid():
    """Крышка сундука. Точка опоры — ось петель: задняя нижняя кромка, по центру. Ставить в
    (0, 3.5, +3.5) относительно опоры сундука; открывать поворотом вокруг X."""
    m = Model()
    W, D = CHEST_W, CHEST_D
    R = D / 2

    def half(rz, ry, n=10):
        return [(rz * math.cos(math.radians(a)), ry * math.sin(math.radians(a))) for a in [180 * i / n for i in range(n + 1)]]
    m.add(prism(half(R - 0.2, 2.4), -W / 2 + 0.2, W / 2 - 0.2, color="gold")).grad("gold", mix(PAL["gold"], PAL["white"], 0.35))
    for x in (-W / 2 + 0.55, 0.0, W / 2 - 0.55):
        m.add(prism(half(R + 0.08, 2.62), x - 0.5, x + 0.5, color="orange" if x else "red"))
    m.add(rbox(W, 0.5, D, 0.22, 1, "orange").move(0, 0.25, 0))
    m.add(rbox(1.5, 1.0, 0.5, 0.3, 1, "cream").move(0, 0.5, -R - 0.1))
    m.add(crystal(0.7, 1.3, 6, 0.5, 0.5).move(0, 2.3, 0), glow="chrono")
    for mm in m.parts.values():
        for mesh in mm:
            mesh.move(0, 0, -R)  # петли на z = 0
    return m


def chest_pedestal():
    m = Model()
    for r, h, y, c0, c1 in ((10.0, 1.7, 0.0, "stoneDark", "stone"), (8.6, 1.6, 1.6, "stone", "cream"), (7.2, 1.5, 3.1, "cream", "cream")):
        m.add(cyl(r, h, 0.4, 28, "stone", r2=r - 0.25, steps=2).move(0, y, 0)).grad(c0, c1)
    m.add(torus(9.75, 0.3, 28, 6, "gold").move(0, 1.0, 0))
    m.add(torus(8.4, 0.28, 28, 6, "orange").move(0, 2.5, 0))
    m.add(torus(6.2, 0.16, 28, 5).move(0, 4.6, 0), glow="gold")
    for x, y, z in ring_pos(8, 9.2, 1.7, math.pi / 8):
        m.add(crystal(0.4, 1.1, 6, 0.45, 0.3).move(x, y - 0.1, z), glow="chrono")
    return m


BELT_R, BELT_W, BELT_N = 27.0, 7.0, 44


def belt_arc():
    """Сегмент кольцевого конвейера: 1/44 круга, середина дуги смотрит на −Z. Точка опоры — ЦЕНТР КОЛЬЦА на уровне пола:
    сегмент i ставится как PivotTo(center * CFrame.Angles(0, i * 2π/44, 0)). Верх ленты на y = 1.2."""
    m = Model()
    d = 360.0 / BELT_N
    a0, a1 = -d / 2 * 1.01, d / 2 * 1.01
    r0, r1 = BELT_R - BELT_W / 2, BELT_R + BELT_W / 2
    m.add(arc_prism(r0 + 0.25, r1 - 0.25, 0.0, 0.95, a0, a1, 3, "metalDark")).grad("dark", "metalDark")
    m.add(arc_prism(r0 + 0.75, r1 - 0.75, 0.8, 1.2, a0, a1, 3, "dark"))
    m.add(arc_prism(BELT_R - 1.6, BELT_R + 1.6, 1.15, 1.24, -d * 0.12, d * 0.12, 1, "gold"))
    for r in (r0 + 0.45, r1 - 0.45):
        path = [(r * math.sin(math.radians(a)), 1.3, -r * math.cos(math.radians(a))) for a in (a0, a0 / 2, 0, a1 / 2, a1)]
        m.add(tube(path, 0.45, 8, color="metal"))
        path2 = [(x, 1.72, z) for x, _, z in path]
        m.add(tube(path2, 0.14, 5, color="orange"))
    for r in (r0 + 0.45, r1 - 0.45):
        m.add(sphere(0.3, 6, 4, "gold").move(0, 1.3, -r).scale(1, 1, 1))
    return m


def portal_ring(c):
    """Портал конвейера: кольцо ~9 стад на подставке, проём смотрит на −Z."""
    m = Model()
    dark = "dark"
    m.add(rbox(7.0, 0.9, 3.2, 0.35, 1, "stoneDark").move(0, 0.45, 0))
    m.add(rbox(5.4, 0.5, 2.4, 0.2, 1, "stone").move(0, 1.1, 0))
    ring = torus(3.75, 0.72, 24, 8, c).rot("x", 90).move(0, 5.2, 0)
    m.add(ring.grad(dark, c))
    for a in (45, 135, 225, 315):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        m.add(torus(0.86, 0.2, 10, 5, "gold").rot("x", 90).rot("z", a).move(3.75 * ca, 5.2 + 3.75 * sa, 0))
    m.add(sphere(1.0, 16, 6).scale(3.2, 3.2, 0.12).move(0, 5.2, 0), glow=c, t=35)
    m.add(torus(2.1, 0.12, 20, 5).rot("x", 90).move(0, 5.2, 0), glow="gold")
    m.add(crystal(0.6, 1.5, 6, 0.45, 0.35).move(0, 9.5, 0), glow=c)
    for s in (-1, 1):
        m.add(crystal(0.38, 1.1, 6, 0.4, 0.3).move(s * 2.9, 0.9, -0.9), glow=c)
    return m


def skin_podium():
    m = Model()
    m.add(cyl(4.0, 0.9, 0.3, 20, "violet", r2=3.8)).grad("dark", "violet")
    m.add(cyl(3.3, 0.6, 0.22, 20, "cream").move(0, 0.8, 0))
    m.add(torus(3.5, 0.14, 20, 5).move(0, 0.95, 0), glow="gold")
    # манекен: стойка, тело, голова, руки
    m.add(cyl(0.9, 0.3, 0.1, 8, "dark", steps=1).move(0, 1.4, 0))
    m.add(cyl(0.2, 1.6, 0.06, 6, "dark").move(0, 1.5, 0))
    body = lathe(fillet([(0, 3.0), (0.9, 3.0), (1.15, 3.9), (0.85, 5.0), (1.2, 5.7), (0.5, 6.1), (0, 6.1)], 0.35), 12, color="cream")
    m.add(body.scale(1, 1, 0.72).grad(mix(PAL["cream"], PAL["orange"], 0.25), "cream"))
    m.add(cyl(0.3, 0.5, 0.1, 8, "cream").move(0, 5.95, 0))
    m.add(sphere(0.95, 10, 6, "cream").scale(1, 1.05, 0.95).move(0, 7.2, 0))
    for s in (-1, 1):
        m.add(tube([(s * 1.1, 5.6, 0), (s * 1.75, 4.6, 0.1), (s * 1.9, 3.6, -0.1)], [0.3, 0.26, 0.24], 6, color="cream"))
        m.add(sphere(0.3, 6, 4, "orange").move(s * 1.9, 3.5, -0.1))
    m.add(sphere(0.22, 6, 4, "dark").move(0, 8.3, 0))
    return m


def leaderboard():
    """Доска лидерборда 16×14: тёмное поле под SurfaceGui смотрит на −Z."""
    m = Model()
    m.add(rbox(14.6, 8.6, 0.6, 0.2, 1, "dark").move(0, 9.3, 0))
    for y in (4.75, 13.85):
        m.add(rbox(16.0, 0.9, 1.0, 0.35, 1, "gold").move(0, y, 0))
    for x in (-7.55, 7.55):
        m.add(rbox(0.9, 9.9, 1.0, 0.35, 1, "orange").move(x, 9.3, 0))
    for x in (-5.6, 5.6):
        m.add(rbox(1.0, 4.6, 0.9, 0.35, 1, "woodDark").move(x, 2.3, 0)).grad("woodDark", "wood")
        m.add(rbox(1.8, 0.6, 2.4, 0.25, 1, "dark").move(x, 0.3, 0))
    for x, y in ((-7.55, 4.75), (7.55, 4.75), (-7.55, 13.85), (7.55, 13.85)):
        m.add(sphere(0.62, 8, 5, "cream").move(x, y, 0))
    m.add(crystal(0.7, 1.5, 6, 0.45, 0.4).move(0, 13.2, 0), glow="chrono")
    return m


def rebirth_altar():
    m = Model()
    cols = ("stoneDark", "stone", "violet", "stone", "cream")
    for i in range(5):
        r = 7.0 - i * 1.0
        c = cols[i]
        m.add(cyl(r, 0.8, 0.22, 20, c, steps=2).move(0, i * 0.7, 0)).grad(mix(PAL[c], PAL["dark"], 0.25), c)
    m.add(cyl(2.4, 0.22, 0.08, 20, steps=1).move(0, 3.5, 0), glow="chrono")
    m.add(torus(2.75, 0.16, 20, 5, "gold").move(0, 3.55, 0))
    for x, y, z in ring_pos(4, 5.4, 0, math.pi / 4):
        m.add(cyl(0.45, 2.3, 0.15, 8, "gold", r2=0.32).move(x, 1.4, z))
        m.add(crystal(0.4, 1.2, 6, 0.45, 0.35).move(x, 3.6, z), glow="violet")
    return m


def statue_pedestal():
    m = Model()
    m.add(cyl(4.0, 1.0, 0.3, 20, "stoneDark", r2=3.8)).grad("dark", "stoneDark")
    m.add(lathe(fillet([(0, 0.9), (3.5, 0.9), (2.9, 1.6), (2.9, 2.9), (3.5, 3.3), (0, 3.3)], 0.4), 20, color="stone")).grad("stoneDark", "stone")
    m.add(cyl(3.6, 0.8, 0.28, 20, "cream").move(0, 3.2, 0))
    m.add(torus(3.0, 0.2, 20, 5, "gold").move(0, 2.25, 0))
    m.add(rbox(2.6, 1.0, 0.4, 0.2, 1, "gold").move(0, 2.25, -2.95))
    m.add(torus(3.0, 0.12, 20, 5).move(0, 4.0, 0), glow="gold")
    return m


def season_portal():
    return portal(("red", "orange"), "gold", "orange", "chrono").scale(12.0 / 14.3)


# ================= БАЗЫ =================
def lock_button():
    """Кнопка замка у ворот: тумба ~9, высота ~2.5. Кнопка — узел Button (белые вершины: цвет задаёт Part.Color,
    ModelLib ставит красный по умолчанию), на ней рельефный замочек (узел Body, не перекрашивается)."""
    m = Model()
    m.add(cyl(4.5, 0.8, 0.28, 20, "dark", r2=4.25)).grad("dark", "steelDark")
    m.add(cyl(4.0, 1.0, 0.28, 20, "steel", r2=3.8).move(0, 0.65, 0)).grad("steelDark", "metal")
    m.add(torus(3.6, 0.28, 20, 6, "gold").move(0, 1.65, 0))
    for x, y, z in ring_pos(6, 4.05, 0.8):
        m.add(sphere(0.28, 6, 4, "gold").move(x, y, z))
    dome = fillet([(0, 1.5), (3.25, 1.5), (3.15, 2.0), (2.2, 2.33), (0, 2.38)], [0, 0.15, 0.4, 0.5, 0], 3)
    m.add(lathe(dome, 20, crease=75, color="white"), node="Button")
    # замочек: корпус + дужка
    m.add(rbox(2.5, 1.9, 0.36, 0.4, 1, "cream").rot("x", 90).move(0, 2.44, -0.75))
    m.add(tube([(0.8 * math.cos(math.radians(a)), 2.42, 0.2 + 1.1 * math.sin(math.radians(a))) for a in (0, 30, 60, 90, 120, 150, 180)], 0.22, 5, color="cream"))
    m.add(sphere(0.3, 6, 4, "dark").scale(1, 0.5, 1).move(0, 2.6, -0.75))
    return m


def collect_plate():
    """Плита сбора дохода 10×10×~0.6: золотая, толстая рамка, большая монета в центре, монетки по углам."""
    m = Model()
    m.add(rbox(9.7, 0.5, 9.7, 0.18, 1, "gold").move(0, 0.25, 0)).grad("dark", "gold", power=0.4)
    for sx, sz, w, d in ((0, -4.4, 10.0, 1.2), (0, 4.4, 10.0, 1.2), (-4.4, 0, 1.2, 10.0), (4.4, 0, 1.2, 10.0)):
        m.add(rbox(w, 0.6, d, 0.25, 1, "orange").move(sx, 0.3, sz))
    for sx, sz, w, d in ((0, -3.55, 6.6, 0.22), (0, 3.55, 6.6, 0.22), (-3.55, 0, 0.22, 6.6), (3.55, 0, 0.22, 6.6)):
        m.add(rbox(w, 0.12, d, 0.05, 1).move(sx, 0.52, sz), glow="gold")
    # большая монета: диск, ободок, внутренний круг
    m.add(cyl(2.5, 0.16, 0.06, 20, "gold", steps=1).move(0, 0.46, 0))
    m.add(torus(2.3, 0.2, 20, 5).scale(1, 0.6, 1).move(0, 0.6, 0), glow="gold")
    m.add(cyl(1.3, 0.1, 0.04, 20, "cream", steps=1).move(0, 0.56, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.add(cyl(0.62, 0.14, 0.05, 10, "gold", steps=1).move(sx * 4.4, 0.56, sz * 4.4))
    return m


def collect_pad():
    m = Model()
    m.add(rbox(10.0, 0.4, 10.0, 0.18, 1, "violet").move(0, 0.2, 0)).grad("dark", "violet")
    m.add(rbox(8.6, 0.16, 8.6, 0.07, 1, "cream").move(0, 0.4, 0))
    for sx, sz, w, d in ((0, -4.6, 9.4, 0.3), (0, 4.6, 9.4, 0.3), (-4.6, 0, 0.3, 9.4), (4.6, 0, 0.3, 9.4)):
        m.add(rbox(w, 0.16, d, 0.07, 1).move(sx, 0.42, sz), glow="gold")
    m.add(cyl(2.2, 0.22, 0.08, 20, "gold", steps=1).move(0, 0.42, 0))
    m.add(torus(1.55, 0.12, 20, 5, "orange").move(0, 0.64, 0))
    m.add(sphere(0.7, 10, 5, "orange").scale(1, 0.25, 1).move(0, 0.64, 0))
    return m


def floor2():
    """Секция пола второго этажа 20×20, верх на y = 2; перила вдоль передней кромки (−Z)."""
    m = Model()
    for x in (-7.0, 0.0, 7.0):
        m.add(rbox(1.2, 1.2, 20.0, 0.3, 1, "woodDark").move(x, 0.6, 0))
    for i in range(5):
        c = "woodLight" if i % 2 == 0 else "wood"
        m.add(rbox(20.0, 0.85, 3.9, 0.25, 1, c).move(0, 1.575, -8.0 + 4.0 * i))
    for x in (-9.4, -3.13, 3.13, 9.4):
        m.add(rbox(0.8, 3.6, 0.8, 0.28, 1, "woodDark").move(x, 3.8, -9.5))
        m.add(sphere(0.52, 8, 5, "gold").move(x, 5.8, -9.5))
    for y, c in ((5.0, "cream"), (3.6, "orange")):
        m.add(tube([(-9.4, y, -9.5), (9.4, y, -9.5)], 0.24, 6, color=c))
    return m


def stairs():
    """Лестница на второй этаж: подъём 22, ширина 8, идёт вверх в сторону −Z (22 ступени, вылет 33)."""
    m = Model()
    n, run = 22, 1.5
    for i in range(n):
        c = "woodLight" if i % 2 == 0 else "wood"
        m.add(rbox(8.0, 0.9, run + 0.12, 0.22, 1, c).move(0, i + 0.55, (n / 2 - i - 0.5) * run))
    ang = math.degrees(math.atan2(n, n * run))
    L = math.hypot(n, n * run)
    for s in (-1, 1):
        m.add(rbox(0.7, 1.3, L, 0.25, 1, "woodDark").rot("x", ang).move(s * 3.9, n / 2 - 0.5, 0))
        pts = []
        for i in (0, 7, 14, 21):
            z = (n / 2 - i - 0.5) * run
            m.add(rbox(0.6, 3.4, 0.6, 0.22, 1, "woodDark").move(s * 3.9, i + 2.4, z))
            m.add(sphere(0.42, 6, 4, "gold").move(s * 3.9, i + 4.3, z))
            pts.append((s * 3.9, i + 3.7, z))
        m.add(tube(pts, 0.22, 6, color="cream"))
    return m


# ================= СЕЗОННЫЙ ОСТРОВ =================
def titan_altar():
    m = Model()
    m.add(rbox(10.0, 1.1, 10.0, 0.4, 2, "stoneDark").move(0, 0.55, 0)).grad("dark", "stoneDark")
    m.add(rbox(8.2, 1.0, 8.2, 0.4, 2, "stone").move(0, 1.5, 0))
    m.add(rbox(6.6, 0.8, 6.6, 0.35, 2, "cream").move(0, 2.3, 0))
    m.add(cyl(2.5, 0.2, 0.08, 20, steps=1).move(0, 2.7, 0), glow="orange")
    m.add(torus(2.8, 0.18, 20, 5, "gold").move(0, 2.75, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.add(cyl(0.55, 1.6, 0.18, 8, "gold", r2=0.4).move(sx * 4.2, 1.0, sz * 4.2))
            m.add(crystal(0.42, 1.3, 6, 0.45, 0.35).move(sx * 4.2, 2.5, sz * 4.2), glow="chrono")
    return m


def cage():
    """Клетка вокруг алтаря: радиус 5, высота 12. Прутья — отдельные детали Bar1…Bar8 (их ломают),
    Base — нижнее кольцо, Top — венец."""
    m = Model()
    m.add(torus(5.0, 0.5, 24, 6, "dark"), node="Base").grad("dark", "violet").move(0, 0.5, 0)
    m.add(torus(1.1, 0.35, 12, 6, "gold").move(0, 11.0, 0), node="Top")
    m.add(crystal(0.6, 1.6, 6, 0.45, 0.35).move(0, 10.6, 0), glow="chrono")
    for i in range(8):
        a = 2 * math.pi * i / 8
        prof = [(5.0, 0.6), (5.0, 4.0), (4.95, 7.0), (4.3, 9.2), (2.8, 10.5), (1.2, 11.0)]
        path = [(r * math.sin(a), y, -r * math.cos(a)) for r, y in prof]
        bar = tube(path, [0.38, 0.34, 0.32, 0.3, 0.28, 0.26], 6, color="violet")
        m.add(bar, node=f"Bar{i + 1}").grad("violet", "chrono")
        m.add(sphere(0.5, 8, 5, "gold").move(5.0 * math.sin(a), 0.9, -5.0 * math.cos(a)), node=f"Bar{i + 1}")
    return m


def pumpkin():
    m = Model()
    lob = lambda th, r, y: 1 + 0.07 * math.cos(8 * th)
    prof = [(1.8 * math.sin(math.pi * j / 8), 1.3 - 1.3 * math.cos(math.pi * j / 8)) for j in range(9)]
    m.add(lathe(prof, 24, crease=80, color="orange", radial=lob)).grad(mix(PAL["orange"], PAL["red"], 0.35), "orange")
    m.add(tube([(0, 2.5, 0), (0.1, 3.0, 0), (0.4, 3.3, 0.1)], [0.26, 0.2, 0.15], 6, color="grassDark"))
    for s in (-1, 1):
        m.add(sphere(0.3, 8, 4).scale(1, 1.15, 0.4).move(s * 0.62, 1.65, -1.62), glow="gold")
    smile = [(1.0 * math.sin(math.radians(a)), 1.25 - 0.45 * math.cos(math.radians(a)), -1.72 + 0.12 * abs(a) / 60) for a in (-60, -30, 0, 30, 60)]
    m.add(tube(smile, 0.11, 5), glow="gold")
    m.add(blob(1.0, 51, 0.15, 8, 5, "grass").scale(0.9, 0.2, 0.6).move(0.7, 2.6, 0.3))
    return m


def torch():
    m = Model()
    m.add(cyl(0.7, 0.4, 0.15, 8, "dark", r2=0.55))
    m.add(cyl(0.2, 3.6, 0.06, 6, "woodDark", r2=0.26).move(0, 0.3, 0)).grad("woodDark", "wood")
    m.add(lathe(fillet([(0, 3.7), (0.35, 3.7), (0.75, 4.5), (0.6, 4.6), (0, 4.6)], 0.1), 8, color="dark"))
    m.add(torus(0.5, 0.1, 8, 4, "gold").move(0, 4.05, 0))
    flame = fillet([(0, 4.5), (0.55, 4.7), (0.6, 5.2), (0.25, 5.9), (0, 6.3)], 0.25)
    m.add(lathe(flame, 8, crease=80), glow="orange")
    m.add(sphere(0.3, 6, 4).scale(1, 1.5, 1).move(0, 5.0, 0), glow="gold")
    return m


def xmas_tree():
    m = Model()
    m.add(cyl(0.6, 1.4, 0.15, 8, "woodDark")).grad("woodDark", "wood")
    for r, y, h in ((3.0, 1.0, 3.2), (2.4, 3.2, 2.9), (1.7, 5.2, 2.6)):
        tier = lathe(fillet([(0, y), (r, y), (r * 0.9, y + 0.4), (0.25, y + h), (0, y + h)], 0.3), 12, crease=70, color="grass")
        m.add(tier.grad("grassDark", "grass"))
        m.add(torus(r * 0.88, 0.22, 12, 5, "cream").scale(1, 0.7, 1).move(0, y + 0.42, 0))
    cols = ("red", "gold", "chrono", "pink")
    for i in range(9):
        lvl = i % 3
        r, y = ((2.9, 1.25), (2.3, 3.45), (1.6, 5.45))[lvl]
        a = i * 2.4
        m.add(sphere(0.3, 6, 4, cols[i % 4]).move(r * math.cos(a), y, r * math.sin(a)))
    m.add(crystal(0.5, 1.3, 4, 0.5, 0.5).move(0, 7.6, 0), glow="gold")
    return m


def snowman():
    m = Model()
    white = mix(PAL["cream"], PAL["white"], 0.6)
    for r, y in ((1.6, 1.4), (1.2, 3.5), (0.9, 5.1)):
        m.add(sphere(r, 14, 8, white).scale(1, 0.92, 1).move(0, y, 0)).grad(mix(white, PAL["chrono"], 0.18), white)
    m.add(cone(0.2, 0.9, 6, "orange").rot("x", -90).move(0, 5.05, -0.8))
    for s in (-1, 1):
        m.add(sphere(0.13, 6, 4, "dark").move(s * 0.32, 5.35, -0.8))
        m.add(tube([(s * 1.0, 3.8, 0), (s * 2.0, 4.4, -0.1), (s * 2.5, 5.0, 0)], 0.09, 4, color="woodDark"))
    for y in (3.2, 3.8):
        m.add(sphere(0.14, 6, 4, "dark").move(0, y, -1.17))
    m.add(torus(0.8, 0.26, 12, 5, "red").move(0, 4.35, 0))
    m.add(rbox(0.5, 1.2, 0.3, 0.12, 1, "red").rot("z", 12).move(0.55, 3.8, -0.85))
    m.add(cyl(1.05, 0.16, 0.06, 12, "dark", steps=1).move(0, 5.75, 0))
    m.add(cyl(0.7, 1.0, 0.12, 12, "dark").move(0, 5.85, 0))
    m.add(torus(0.71, 0.1, 12, 4, "gold").move(0, 6.1, 0))
    return m


def palm():
    m = Model()
    m.add(blob(1.0, 61, 0.12, 10, 5, "cream").scale(2.2, 0.45, 2.0).move(0, 0.25, 0)).grad(mix(PAL["cream"], PAL["orange"], 0.3), "cream")
    path = [(0.0, 0.3, 0), (0.25, 2.0, 0), (0.75, 4.0, 0), (1.5, 6.0, 0), (2.4, 7.8, 0)]
    m.add(tube(path, [0.62, 0.55, 0.48, 0.42, 0.36], 8, color="wood")).grad("woodDark", "woodLight")
    for i, p in enumerate(path[1:-1]):
        m.add(torus(0.56 - 0.07 * i, 0.09, 8, 4, "woodDark").rot("z", -12 - 6 * i).move(*p))
    top = (2.4, 7.9, 0)
    for i in range(7):
        a = 2 * math.pi * i / 7 + 0.3
        dx, dz = math.cos(a), math.sin(a)
        leaf = [(top[0] + dx * t * 3.6, top[1] + 1.0 * math.sin(t * 2.2) - 1.7 * t * t, top[2] + dz * t * 3.6) for t in (0, 0.25, 0.5, 0.75, 1.0)]
        m.add(tube(leaf, [0.25, 0.6, 0.65, 0.45, 0.08], 6, ry=[0.14, 0.14, 0.12, 0.1, 0.05], color="grass")).grad("grassDark", "grassLight")
    for dx, dz in ((0.4, 0.3), (-0.35, 0.25), (0.05, -0.45)):
        m.add(sphere(0.38, 8, 5, "woodDark").move(top[0] + dx, top[1] - 0.45, top[2] + dz))
    return m


def shells():
    m = Model()
    m.add(blob(1.0, 62, 0.12, 10, 5, "cream").scale(2.4, 0.4, 1.9).move(0, 0.22, 0)).grad(mix(PAL["cream"], PAL["orange"], 0.35), "cream")
    rib = lambda th, r, y: 1 + 0.08 * math.cos(9 * th)
    sh = lathe([(1.1 * math.sin(math.pi * j / 10), 0.55 * (1 - math.cos(math.pi * j / 10)) / 2 * 2) for j in range(6)], 18, crease=80, color="pink", radial=rib)
    m.add(sh.scale(1, 1, 0.9).rot("x", -55).move(-0.9, 0.5, 0.2)).grad("pink", "cream")
    m.add(sphere(0.32, 8, 5, mix(PAL["white"], PAL["chrono"], 0.15)).move(-0.9, 0.62, -0.25))
    # морская звезда
    for i in range(5):
        a = 2 * math.pi * i / 5
        m.add(cone(0.3, 0.95, 6, "orange", bevel=0.08).scale(1, 1, 0.5).rot("x", 90).rot("y", math.degrees(a)).move(1.1, 0.62, 0.3))
    m.add(sphere(0.34, 8, 4, "orange").scale(1, 0.55, 1).move(1.1, 0.62, 0.3))
    # закрученная ракушка
    sp = [(0.2 + 0.5 * t) for t in (0, 0.25, 0.5, 0.75, 1.0)]
    for i, r in enumerate(sp):
        m.add(sphere(r, 8, 5, mix(PAL["violet"], PAL["cream"], 0.55 + 0.08 * i)).move(0.2 + 0.0 * i, 0.55 + 0.1 * i, -1.0 + 0.32 * i - 0.6))
    return m


def sakura():
    pink2 = mix(PAL["pink"], PAL["white"], 0.45)
    return tree((mix(PAL["pink"], PAL["red"], 0.25), PAL["pink"], pink2), "cream", ("dirtDark", "dirt"))


def flowers():
    m = Model()
    m.add(blob(1.0, 63, 0.12, 10, 5, "grass").scale(1.8, 0.35, 1.5).move(0, 0.2, 0)).grad("grassDark", "grass")
    spec = ((-0.8, 0.1, 2.3, "pink", "gold"), (0.7, -0.3, 2.9, "gold", "orange"), (0.2, 0.7, 1.8, "violet", "gold"), (-0.2, -0.8, 1.5, "red", "cream"))
    for k, (x, z, h, cp, cc) in enumerate(spec):
        m.add(tube([(x, 0.2, z), (x + 0.1, h * 0.5, z), (x, h, z)], 0.09, 5, color="grassDark"))
        m.add(sphere(0.3, 6, 4, "grass").scale(1.3, 0.3, 0.7).rot("y", 40 * k).move(x + 0.25, h * 0.45, z))
        for i in range(5):
            a = 2 * math.pi * i / 5 + k
            m.add(sphere(0.3, 6, 4, cp).scale(1, 0.4, 1).move(x + 0.36 * math.cos(a), h + 0.02, z + 0.36 * math.sin(a)))
        m.add(sphere(0.24, 6, 4, cc).move(x, h + 0.1, z))
    return m


def planet():
    m = Model()
    m.add(cyl(1.3, 0.4, 0.14, 10, "dark", r2=1.0))
    m.add(cyl(0.16, 2.0, 0.05, 6, "steel").move(0, 0.3, 0))
    band = lambda p: mix(PAL["violet"], PAL["pink"], 0.5 + 0.5 * math.sin(p[1] * 3.2))
    m.add(sphere(1.9, 16, 10).paint_fn(band).rot("z", 15).move(0, 4.0, 0))
    m.add(torus(2.9, 0.42, 28, 6, ry=0.08).rot("z", 15).rot("x", 10).move(0, 4.0, 0), glow="gold")
    m.add(sphere(0.45, 8, 5, "cream").move(2.6, 5.9, -0.6))
    m.add(sphere(0.28, 6, 4, "chrono").move(-2.4, 2.4, 0.8))
    return m


def meteor():
    m = Model()
    m.add(blob(1.0, 71, 0.12, 10, 5, "stoneDark").scale(2.6, 0.5, 2.3).move(0, 0.25, 0)).grad("dark", "stoneDark")
    m.add(blob(1.6, 72, 0.25, 12, 7, "steelDark", freq=2.2).move(0.2, 1.7, 0)).grad("dark", "steel")
    for x, y, z, r in ((0.9, 2.6, -0.8, 0.45), (-0.9, 1.9, -0.9, 0.38), (0.4, 1.2, -1.4, 0.3), (-0.5, 2.9, 0.4, 0.35), (1.6, 1.5, 0.5, 0.32)):
        m.add(blob(r, int(x * 10 + 80), 0.2, 6, 4).move(x, y, z), glow="orange")
    for i, (x, z) in enumerate(((-2.0, 0.6), (1.9, -1.3), (-1.2, -1.7))):
        m.add(crystal(0.25, 0.9, 5, 0.4, 0.3).rot("z", 20 - 20 * i).move(x, 0.3, z), glow="gold")
    return m


def coral():
    m = Model()
    m.add(blob(1.0, 81, 0.2, 10, 6, "stone").scale(2.0, 0.7, 1.7).move(0, 0.45, 0)).grad("stoneDark", "stone")

    def branch(x, z, h, lean, c, r=0.3):
        tipc = mix(PAL[c], PAL["white"], 0.4)
        p = [(x, 0.6, z), (x + lean * 0.3, 0.6 + h * 0.5, z), (x + lean, 0.6 + h, z + 0.2 * lean)]
        m.add(tube(p, [r, r * 0.85, r * 0.7], 6, color=c)).grad(c, tipc)
        m.add(sphere(r * 0.85, 6, 4, tipc).move(*p[-1]))
        q = [p[1], (p[1][0] - lean * 0.6 - 0.3, p[1][1] + h * 0.35, p[1][2] + 0.3)]
        m.add(tube(q, [r * 0.7, r * 0.55], 5, color=c)).grad(c, tipc)
        m.add(sphere(r * 0.65, 6, 4, tipc).move(*q[-1]))
    branch(0.0, 0.0, 3.6, 0.5, "red", 0.36)
    branch(-1.0, 0.3, 2.6, -0.6, "pink")
    branch(0.9, -0.4, 2.2, 0.7, "orange")
    branch(0.2, 0.9, 1.8, -0.3, "violet", 0.26)
    for x, z in ((-1.5, -0.6), (1.5, 0.7)):
        m.add(sphere(0.4, 8, 4, "chrono").scale(1, 0.6, 1).move(x, 0.75, z))
    return m


def bubbles():
    m = Model()
    m.add(blob(1.0, 91, 0.15, 10, 5, "cream").scale(1.6, 0.35, 1.4).move(0, 0.2, 0)).grad(mix(PAL["cream"], PAL["orange"], 0.3), "cream")
    m.add(sphere(0.5, 8, 5, "pink").scale(1.2, 0.6, 1).move(0.3, 0.5, -0.2))
    for x, y, z, r in ((0, 1.6, 0, 0.75), (0.8, 2.9, 0.3, 0.55), (-0.6, 3.6, -0.2, 0.95), (0.3, 5.0, 0.2, 0.45), (-0.2, 5.9, -0.3, 0.65), (0.6, 6.8, 0, 0.35)):
        m.add(sphere(r, 12, 7).move(x, y, z), glow="chrono", t=60)
        m.add(sphere(r * 0.22, 6, 4, "white").move(x - r * 0.45, y + r * 0.45, z - r * 0.55))
    return m


# ================= ПРЕДМЕТ =================
def club():
    """Дубинка в руку, длина ~4 вдоль Y. Точка опоры — низ рукояти."""
    m = Model()
    m.add(sphere(0.3, 8, 5, "gold").move(0, 0.3, 0))
    m.add(tube([(0, 0.4, 0), (0, 1.6, 0), (0, 2.7, 0)], [0.2, 0.22, 0.3], 8, color="wood")).grad("woodDark", "woodLight")
    for y in (0.75, 1.05, 1.35):
        m.add(torus(0.23, 0.07, 8, 4, "dark").move(0, y, 0))
    head = lathe(fillet([(0, 2.5), (0.55, 2.55), (0.85, 3.2), (0.7, 3.8), (0, 4.0)], [0, 0.2, 0.4, 0.35, 0], 3), 12, crease=75, color="wood")
    m.add(head.grad("woodDark", "wood"))
    m.add(torus(0.6, 0.1, 12, 4, "orange").move(0, 2.65, 0))
    for x, y, z in ring_pos(6, 0.82, 3.25):
        m.add(sphere(0.14, 6, 4, "gold").move(x, y, z))
    return m


MODELS = {
    "chest": (chest, 5000, "Золотой сундук — корпус с монетами и самоцветами (10×~5×7)"),
    "chestLid": (chest_lid, 2000, "Крышка сундука; опора — ось петель (ставить в (0, 3.5, +3.5) от опоры сундука, открывать вокруг X)", (0, 0, 0)),
    "chestPedestal": (chest_pedestal, 5000, "Пьедестал под сундук, 3 яруса"),
    "beltArc": (belt_arc, 2000, "Сегмент кольцевого конвейера 1/44 (R=27, ширина 7); опора — центр кольца", (0, 0, 0)),
    "portalStart": (lambda: portal_ring("chrono").scale(0.84), 2000, "Портал начала конвейера (бирюзовый)"),
    "portalEnd": (lambda: portal_ring("violet").scale(0.84), 2000, "Портал конца конвейера (фиолетовый)"),
    "skinPodium": (skin_podium, 2000, "Подиум с манекеном для скинов"),
    "leaderboard": (leaderboard, 2000, "Доска лидерборда 16×14 на ножках"),
    "rebirthAltar": (rebirth_altar, 5000, "Алтарь ребёрса, 5 ступеней, верх светится"),
    "statuePedestal": (statue_pedestal, 2000, "Пьедестал под статую-маскота"),
    "seasonPortal": (season_portal, 2000, "Сезонный портал-арка ~12"),
    "lockButton": (lock_button, 2000, "Кнопка замка: тумба ~9, кнопка — узел Button (перекрашивается), замочек"),
    "collectPlate": (collect_plate, 2000, "Плита сбора дохода 10×10, золотая, с монетой"),
    "collectPad": (collect_pad, 2000, "Плита сбора дохода 10×10 (старый вариант, см. collectPlate)"),
    "floor2": (floor2, 5000, "Секция пола второго этажа 20×20 с перилами (верх на 2.0)"),
    "stairs": (stairs, 5000, "Лестница на второй этаж: подъём 22, ширина 8, вверх к −Z"),
    "titanAltar": (titan_altar, 2000, "Алтарь сезонного Титана 10×10"),
    "cage": (cage, 5000, "Клетка алтаря: прутья Bar1…Bar8 отдельными деталями"),
    "s1Pumpkin": (pumpkin, 2000, "Сезон 1 (Хэллоуин): тыква"),
    "s1Torch": (torch, 2000, "Сезон 1 (Хэллоуин): факел"),
    "s2Tree": (xmas_tree, 2000, "Сезон 2 (Новый год): ёлка"),
    "s2Snowman": (snowman, 2000, "Сезон 2 (Новый год): снеговик"),
    "s3Palm": (palm, 2000, "Сезон 3 (Лето): пальма"),
    "s3Shells": (shells, 2000, "Сезон 3 (Лето): ракушки"),
    "s4Sakura": (sakura, 2000, "Сезон 4 (Весна): сакура"),
    "s4Flowers": (flowers, 2000, "Сезон 4 (Весна): цветы"),
    "s5Planet": (planet, 2000, "Сезон 5 (Космос): планета"),
    "s5Meteor": (meteor, 2000, "Сезон 5 (Космос): метеорит"),
    "s6Coral": (coral, 2000, "Сезон 6 (Глубина): кораллы"),
    "s6Bubbles": (bubbles, 2000, "Сезон 6 (Глубина): пузыри"),
    "club": (club, 2000, "Дубинка в руку, длина ~4"),
}
