"""Мини-библиотека процедурных мешей для Chrono Heist Tycoon (numpy + stdlib).

Система координат = Roblox: Y вверх, перед модели смотрит на −Z, единица = 1 стад.
Каждый примитив — замкнутая поверхность со сглаженными нормалями (crease — угол, после которого ребро
остаётся жёстким) и цветами вершин. Экспорт — бинарный glTF (.glb): POSITION, NORMAL, COLOR_0.
"""
import json
import math
import struct

import numpy as np

# ---------- цвета ----------
def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


PAL = {
    "orange": hexc("#FFB347"), "gold": hexc("#FFE066"), "chrono": hexc("#00E5FF"), "violet": hexc("#7B2FF7"),
    "red": hexc("#FF2E63"), "dark": hexc("#2A2140"), "grass": hexc("#7DD87A"), "cream": hexc("#FFF4DE"),
    "white": hexc("#FFFFFF"),
    # производные пастельные тона (в духе палитры)
    "wood": hexc("#C98B5A"), "woodDark": hexc("#9A6240"), "woodLight": hexc("#E8B27E"),
    "dirt": hexc("#B07A5B"), "dirtDark": hexc("#6B4A5E"), "stone": hexc("#CFC6D8"), "stoneDark": hexc("#9C93B0"),
    "metal": hexc("#A9BCD0"), "metalDark": hexc("#6F83A0"), "steel": hexc("#5B6B8C"), "steelDark": hexc("#3B4263"),
    "grassDark": hexc("#4FB86A"), "grassLight": hexc("#A8EE8C"), "pink": hexc("#FF9EC4"),
}


def mix(a, b, t):
    return np.asarray(a) * (1 - t) + np.asarray(b) * t


def col(c):
    return PAL[c] if isinstance(c, str) and not c.startswith("#") else (hexc(c) if isinstance(c, str) else np.asarray(c, float))


# ---------- меш ----------
class Mesh:
    def __init__(self, V, N, C, F):
        self.V = np.asarray(V, float).reshape(-1, 3)
        self.N = np.asarray(N, float).reshape(-1, 3)
        self.C = np.asarray(C, float).reshape(-1, 3)
        self.F = np.asarray(F, np.int64).reshape(-1, 3)

    @property
    def tris(self):
        return len(self.F)

    def copy(self):
        return Mesh(self.V.copy(), self.N.copy(), self.C.copy(), self.F.copy())

    # --- преобразования (возвращают self) ---
    def move(self, x=0.0, y=0.0, z=0.0):
        self.V = self.V + np.array([x, y, z], float)
        return self

    def apply(self, M):
        """M — 3×3. Нормали — через обратную транспонированную."""
        M = np.asarray(M, float)
        self.V = self.V @ M.T
        n = self.N @ np.linalg.inv(M)
        self.N = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
        if np.linalg.det(M) < 0:
            self.F = self.F[:, ::-1].copy()
        return self

    def scale(self, sx, sy=None, sz=None):
        sy = sx if sy is None else sy
        sz = sx if sz is None else sz
        return self.apply(np.diag([sx, sy, sz]))

    def rot(self, axis, deg):
        a = math.radians(deg)
        c, s = math.cos(a), math.sin(a)
        M = {"x": [[1, 0, 0], [0, c, -s], [0, s, c]],
             "y": [[c, 0, s], [0, 1, 0], [-s, 0, c]],
             "z": [[c, -s, 0], [s, c, 0], [0, 0, 1]]}[axis]
        return self.apply(M)

    # --- покраска ---
    def paint(self, c):
        self.C = np.tile(col(c), (len(self.V), 1))
        return self

    def grad(self, c0, c1, axis=1, power=1.0):
        """Градиент вдоль оси от c0 (минимум) к c1 (максимум) в пределах габарита меша."""
        v = self.V[:, axis]
        lo, hi = v.min(), v.max()
        t = ((v - lo) / max(hi - lo, 1e-9)) ** power
        self.C = np.outer(1 - t, col(c0)) + np.outer(t, col(c1))
        return self

    def paint_fn(self, fn):
        self.C = np.array([fn(p) for p in self.V], float)
        return self

    def bounds(self):
        return self.V.min(axis=0), self.V.max(axis=0)


def merge(*meshes):
    ms = []
    for m in meshes:
        if isinstance(m, (list, tuple)):
            ms += list(m)
        elif m is not None:
            ms.append(m)
    V, N, C, F, off = [], [], [], [], 0
    for m in ms:
        V.append(m.V); N.append(m.N); C.append(m.C); F.append(m.F + off)
        off += len(m.V)
    return Mesh(np.vstack(V), np.vstack(N), np.vstack(C), np.vstack(F))


def build(V, F, crease=60.0, color="cream", orient="volume"):
    """Сырые вершины/треугольники → Mesh со сглаженными нормалями.

    orient: "volume" — развернуть грани наружу по знаку объёма (для замкнутых поверхностей),
            "center" — каждую грань отдельно от центра (для выпуклых/звёздных форм), None — как есть.
    """
    V = np.asarray(V, float).reshape(-1, 3)
    F = np.asarray(F, np.int64).reshape(-1, 3)
    # сварка совпадающих вершин
    keys = np.round(V / 1e-4).astype(np.int64)
    _, first, inv = np.unique(keys, axis=0, return_index=True, return_inverse=True)
    inv = inv.reshape(-1)
    W = V[first]
    F = inv[F]
    # вырожденные грани — прочь
    a, b, c = W[F[:, 0]], W[F[:, 1]], W[F[:, 2]]
    fn = np.cross(b - a, c - a)
    area = np.linalg.norm(fn, axis=1)
    keep = area > 1e-9
    F, fn, area = F[keep], fn[keep], area[keep]
    if orient == "center":
        ctr = W.mean(axis=0)
        cen = (W[F[:, 0]] + W[F[:, 1]] + W[F[:, 2]]) / 3 - ctr
        flip = np.einsum("ij,ij->i", fn, cen) < 0
        F[flip] = F[flip][:, ::-1]
        fn[flip] *= -1
    elif orient == "volume":
        vol = np.einsum("ij,ij->i", W[F[:, 0]], np.cross(W[F[:, 1]], W[F[:, 2]])).sum()
        if vol < 0:
            F = F[:, ::-1].copy()
            fn = -fn
    unit = fn / area[:, None]
    # нормали углов: среднее (по площади) нормалей соседних граней в пределах crease
    inc = [[] for _ in range(len(W))]
    for fi, tri in enumerate(F):
        for v in tri:
            inc[v].append(fi)
    cosc = math.cos(math.radians(crease))
    outV, outN, index, outF = [], [], {}, []
    for fi, tri in enumerate(F):
        row = []
        for v in tri:
            fs = inc[v]
            n = np.zeros(3)
            for g in fs:
                if unit[fi] @ unit[g] >= cosc:
                    n += fn[g]
            ln = np.linalg.norm(n)
            n = n / ln if ln > 1e-12 else unit[fi]
            key = (int(v), int(round(n[0] * 500)), int(round(n[1] * 500)), int(round(n[2] * 500)))
            j = index.get(key)
            if j is None:
                j = len(outV)
                index[key] = j
                outV.append(W[v]); outN.append(n)
            row.append(j)
        outF.append(row)
    m = Mesh(outV, outN, np.zeros((len(outV), 3)), outF)
    return m.paint(color)


# ---------- примитивы ----------
def rbox(sx, sy, sz, r=0.3, k=2, color="cream"):
    """Скруглённый брусок с центром в нуле. r — радиус скругления, k — сегментов на четверть дуги."""
    h = np.array([sx, sy, sz], float) / 2
    r = min(r, h.min())
    us, offs = [], []
    for i in range(k + 1):
        us.append(math.tan(math.radians(-45 + 45 * i / k))); offs.append(-1)
    for i in range(k + 1):
        us.append(math.tan(math.radians(45 * i / k))); offs.append(1)
    m = len(us)
    V, F = [], []
    for a in range(3):
        b, c = (a + 1) % 3, (a + 2) % 3
        for s in (-1, 1):
            base = len(V)
            for i in range(m):
                for j in range(m):
                    q = np.zeros(3); q[a] = s; q[b] = us[i]; q[c] = us[j]
                    d = q / np.linalg.norm(q)
                    o = np.zeros(3)
                    o[a] = s * (h[a] - r); o[b] = offs[i] * (h[b] - r); o[c] = offs[j] * (h[c] - r)
                    V.append(o + r * d)
            for i in range(m - 1):
                for j in range(m - 1):
                    p0 = base + i * m + j
                    F += [[p0, p0 + m, p0 + m + 1], [p0, p0 + m + 1, p0 + 1]]
    return build(V, F, crease=50, color=color, orient="center")


def fillet(points, radius, steps=3):
    """Скругляет углы ломаной (r, y). radius — число или список по точкам."""
    pts = [np.asarray(p, float) for p in points]
    n = len(pts)
    rad = radius if isinstance(radius, (list, tuple)) else [radius] * n
    out = [pts[0]]
    for i in range(1, n - 1):
        p0, p, p1 = pts[i - 1], pts[i], pts[i + 1]
        l0, l1 = np.linalg.norm(p - p0), np.linalg.norm(p1 - p)
        d = min(rad[i], 0.45 * l0, 0.45 * l1)
        if d <= 1e-6:
            out.append(p)
            continue
        a = p + (p0 - p) / l0 * d
        b = p + (p1 - p) / l1 * d
        for s in range(steps + 1):
            t = s / steps
            out.append((1 - t) ** 2 * a + 2 * t * (1 - t) * p + t * t * b)
    out.append(pts[-1])
    return out


def lathe(profile, seg=16, crease=60, color="cream", radial=None):
    """Тело вращения вокруг Y. profile — [(r, y)…]; концы с r>0 закрываются крышкой.
    radial(theta, r, y) → множитель радиуса (для неровных форм)."""
    prof = [(float(r), float(y)) for r, y in profile]
    if prof[0][0] > 1e-6:
        prof.insert(0, (0.0, prof[0][1]))
    if prof[-1][0] > 1e-6:
        prof.append((0.0, prof[-1][1]))
    V, F = [], []
    for r, y in prof:
        for i in range(seg):
            th = 2 * math.pi * i / seg
            rr = r * (radial(th, r, y) if radial else 1.0)
            V.append([rr * math.cos(th), y, rr * math.sin(th)])
    for j in range(len(prof) - 1):
        for i in range(seg):
            a = j * seg + i
            b = j * seg + (i + 1) % seg
            F += [[a, b, b + seg], [a, b + seg, a + seg]]
    return build(V, F, crease=crease, color=color)


def cyl(r, h, bevel=0.2, seg=16, color="cream", r2=None, steps=3):
    """Цилиндр/усечённый конус со скруглёнными кромками, низ на y=0."""
    r2 = r if r2 is None else r2
    prof = fillet([(0, 0), (r, 0), (r2, h), (0, h)], bevel, steps)
    return lathe(prof, seg, color=color)


def sphere(r=1.0, seg=14, rings=8, color="cream"):
    prof = [(r * math.sin(math.pi * j / rings), -r * math.cos(math.pi * j / rings)) for j in range(rings + 1)]
    prof[0] = (0.0, -r); prof[-1] = (0.0, r)
    return lathe(prof, seg, crease=80, color=color)


def _noise(seed, freq=1.6, n=5):
    rng = np.random.default_rng(seed)
    K = rng.normal(size=(n, 3)) * freq
    P = rng.uniform(0, 2 * math.pi, n)
    return lambda d: float(np.sin(K @ d + P).mean())


def blob(r=1.0, seed=1, amp=0.18, seg=12, rings=7, color="cream", freq=1.6):
    """Мягкий «комок» — сфера с плавной неровностью (камни, кроны, кусты)."""
    m = sphere(1.0, seg, rings)
    f = _noise(seed, freq)
    V = np.array([p * (1 + amp * f(p)) * r for p in m.V])
    return build(V, m.F, crease=80, color=color)


def crystal(r=1.0, h=4.0, sides=6, tip=0.3, base_tip=0.15, color="chrono", twist=0.0):
    """Гранёный кристалл: призма с острой верхушкой, низ на y=0."""
    prof = [(0, 0), (r * 0.75, h * base_tip), (r, h * (1 - tip)), (0, h)]
    m = lathe(prof, sides, crease=20, color=color)
    if twist:
        m.rot("y", twist)
    return m


def cone(r, h, seg=10, color="cream", bevel=0.0):
    prof = [(0, 0), (r, 0), (0, h)]
    if bevel:
        prof = fillet(prof, bevel)
    return lathe(prof, seg, crease=50, color=color)


def tube(path, r=0.3, sides=8, closed=False, color="cream", ry=None, crease=60):
    """Труба вдоль ломаной path. r — радиус (число или список по точкам), ry — второй радиус (эллипс)."""
    P = [np.asarray(p, float) for p in path]
    n = len(P)
    rs = r if isinstance(r, (list, tuple)) else [r] * n
    rys = rs if ry is None else (ry if isinstance(ry, (list, tuple)) else [ry] * n)
    T = []
    for i in range(n):
        if closed:
            t = P[(i + 1) % n] - P[i - 1]
        else:
            t = P[min(i + 1, n - 1)] - P[max(i - 1, 0)]
        T.append(t / np.linalg.norm(t))
    up = np.array([0, 1, 0.0]) if abs(T[0][1]) < 0.9 else np.array([1, 0, 0.0])
    nrm = np.cross(T[0], up); nrm /= np.linalg.norm(nrm)
    V, F = [], []
    frames = []
    for i in range(n):
        if i > 0:  # параллельный перенос
            nrm = nrm - T[i] * (nrm @ T[i])
            nrm /= np.linalg.norm(nrm)
        frames.append((nrm.copy(), np.cross(T[i], nrm)))
    for i in range(n):
        nn, bb = frames[i]
        for s in range(sides):
            a = 2 * math.pi * s / sides
            V.append(P[i] + nn * math.cos(a) * rs[i] + bb * math.sin(a) * rys[i])
    rings = n if closed else n - 1
    for i in range(rings):
        i2 = (i + 1) % n
        for s in range(sides):
            a = i * sides + s; b = i * sides + (s + 1) % sides
            c = i2 * sides + (s + 1) % sides; d = i2 * sides + s
            F += [[a, b, c], [a, c, d]]
    if not closed:
        for i, flip in ((0, False), (n - 1, True)):
            ci = len(V); V.append(P[i])
            for s in range(sides):
                a = i * sides + s; b = i * sides + (s + 1) % sides
                F.append([ci, b, a] if not flip else [ci, a, b])
    return build(V, F, crease=crease, color=color)


def torus(R=2.0, r=0.3, seg=20, sides=8, color="cream", ry=None):
    """Тор в плоскости XZ с центром в нуле."""
    path = [(R * math.cos(2 * math.pi * i / seg), 0, R * math.sin(2 * math.pi * i / seg)) for i in range(seg)]
    return tube(path, r, sides, closed=True, color=color, ry=ry)


def arc(R, a0, a1, n, y=0.0, plane="xy"):
    """Точки дуги радиуса R от угла a0 до a1 (градусы)."""
    out = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        if plane == "xy":
            out.append((R * math.cos(a), y + R * math.sin(a), 0.0))
        else:
            out.append((R * math.cos(a), y, R * math.sin(a)))
    return out


def prism(poly, x0, x1, crease=40, color="cream"):
    """Выдавливание выпуклого контура [(z, y)…] вдоль X от x0 до x1."""
    n = len(poly)
    V = [(x0, y, z) for z, y in poly] + [(x1, y, z) for z, y in poly]
    cz = sum(p[0] for p in poly) / n; cy = sum(p[1] for p in poly) / n
    V += [(x0, cy, cz), (x1, cy, cz)]
    F = []
    for i in range(n):
        j = (i + 1) % n
        F += [[i, j, n + j], [i, n + j, n + i], [2 * n, j, i], [2 * n + 1, n + i, n + j]]
    return build(V, F, crease=crease, color=color)


def arc_prism(r0, r1, y0, y1, a0, a1, n=4, color="cream"):
    """Дуговой брусок вокруг оси Y: радиусы r0..r1, высоты y0..y1, углы a0..a1 (градусы, 0 = направление −Z)."""
    V, F = [], []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        s, c = math.sin(a), -math.cos(a)
        V += [(r0 * s, y0, r0 * c), (r1 * s, y0, r1 * c), (r1 * s, y1, r1 * c), (r0 * s, y1, r0 * c)]
    for i in range(n):
        b = i * 4
        for k in range(4):
            p, q = b + k, b + (k + 1) % 4
            F += [[p, q, q + 4], [p, q + 4, p + 4]]
    e = n * 4
    F += [[0, 1, 2], [0, 2, 3], [e, e + 2, e + 1], [e, e + 3, e + 2]]
    return build(V, F, crease=50, color=color)


# ---------- GLB ----------
def _pad(b, fill=b"\x00"):
    return b + fill * ((4 - len(b) % 4) % 4)


def write_glb(path, nodes):
    """nodes: {имя: Mesh}. Узел с именем Glow_RRGGBB[_Tnn] получает цветной светящийся материал."""
    buf = bytearray()
    views, accessors, meshes, gnodes, materials = [], [], [], [], []
    materials.append({"name": "VertexColor", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.9}})

    def add(arr, target, ctype, typ, minmax=False):
        nonlocal buf
        data = arr.tobytes()
        off = len(buf)
        buf += _pad(data)
        views.append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
        acc = {"bufferView": len(views) - 1, "componentType": ctype, "count": len(arr), "type": typ}
        if minmax:
            acc["min"] = [float(x) for x in arr.min(axis=0)]
            acc["max"] = [float(x) for x in arr.max(axis=0)]
        accessors.append(acc)
        return len(accessors) - 1

    for name, m in nodes.items():
        pos = m.V.astype("<f4")
        nor = m.N.astype("<f4")
        rgba = np.hstack([np.clip(m.C, 0, 1), np.ones((len(m.C), 1))]).astype("<f4")
        if len(pos) < 65536:
            idx = m.F.astype("<u2").reshape(-1); ict = 5123
        else:
            idx = m.F.astype("<u4").reshape(-1); ict = 5125
        mat = 0
        parts = name.split("_")
        if parts[0] == "Glow" and len(parts) > 1 and len(parts[1]) == 6:
            c = hexc(parts[1])
            alpha = 1.0
            for p in parts[2:]:
                if p.startswith("T") and p[1:].isdigit():
                    alpha = 1 - int(p[1:]) / 100
            mdef = {"name": name, "pbrMetallicRoughness": {"baseColorFactor": [float(c[0]), float(c[1]), float(c[2]), alpha],
                                                             "metallicFactor": 0.0, "roughnessFactor": 0.6},
                    "emissiveFactor": [float(c[0]), float(c[1]), float(c[2])]}
            if alpha < 1:
                mdef["alphaMode"] = "BLEND"
            materials.append(mdef)
            mat = len(materials) - 1
        prim = {"attributes": {"POSITION": add(pos, 34962, 5126, "VEC3", True), "NORMAL": add(nor, 34962, 5126, "VEC3"),
                               "COLOR_0": add(rgba, 34962, 5126, "VEC4")},
                "indices": add(idx.reshape(-1, 1), 34963, ict, "SCALAR"), "material": mat, "mode": 4}
        meshes.append({"name": name, "primitives": [prim]})
        gnodes.append({"name": name, "mesh": len(meshes) - 1})
    gltf = {"asset": {"version": "2.0", "generator": "chrono-heist-models"}, "scene": 0,
            "scenes": [{"name": "Scene", "nodes": list(range(len(gnodes)))}], "nodes": gnodes, "meshes": meshes,
            "materials": materials, "accessors": accessors, "bufferViews": views, "buffers": [{"byteLength": len(buf)}]}
    js = _pad(json.dumps(gltf, separators=(",", ":")).encode(), b" ")
    total = 12 + 8 + len(js) + 8 + len(buf)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON")); f.write(js)
        f.write(struct.pack("<I4s", len(buf), b"BIN\x00")); f.write(bytes(buf))
