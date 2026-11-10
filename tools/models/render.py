"""Простой программный рендер (z-буфер, numpy + Pillow) — посмотреть модели без Studio."""
import math

import numpy as np
from PIL import Image, ImageDraw

from meshlib import hexc

BG = hexc("#BFE9FF")


def render(nodes, size=360, yaw=-35, pitch=22):
    V, N, C, F, A = [], [], [], [], []
    off = 0
    for name, m in nodes.items():
        c = m.C.copy()
        alpha = 1.0
        parts = name.split("_")
        if parts[0] == "Glow":
            c = np.tile(hexc(parts[1]), (len(c), 1)) * 0.75 + c * 0.25
            for p in parts[2:]:
                if p.startswith("T"):
                    alpha = 1 - int(p[1:]) / 100
        V.append(m.V); N.append(m.N); C.append(c); F.append(m.F + off)
        A += [(alpha, parts[0] == "Glow")] * len(m.F)
        off += len(m.V)
    V, N, C, F = np.vstack(V), np.vstack(N), np.vstack(C), np.vstack(F)
    # камера смотрит на перед модели (−Z) чуть сбоку и сверху
    ya, pa = math.radians(yaw), math.radians(-pitch)
    Ry = np.array([[math.cos(ya), 0, math.sin(ya)], [0, 1, 0], [-math.sin(ya), 0, math.cos(ya)]])
    Rx = np.array([[1, 0, 0], [0, math.cos(pa), -math.sin(pa)], [0, math.sin(pa), math.cos(pa)]])
    R = Rx @ Ry
    P = V @ R.T
    Nn = N @ R.T
    P[:, 2] *= -1; Nn[:, 2] *= -1  # к камере = +z
    P[:, 0] *= -1; Nn[:, 0] *= -1
    lo, hi = P.min(axis=0), P.max(axis=0)
    s = (size * 0.86) / max(hi[0] - lo[0], hi[1] - lo[1])
    X = (P[:, 0] - (lo[0] + hi[0]) / 2) * s + size / 2
    Y = size / 2 - (P[:, 1] - (lo[1] + hi[1]) / 2) * s
    Z = P[:, 2]
    L = np.array([0.35, 0.75, 0.55]); L /= np.linalg.norm(L)
    img = np.tile(BG, (size, size, 1))
    zb = np.full((size, size), -1e9)
    order = np.argsort([a[0] < 1 for a in A], kind="stable")  # прозрачное — последним
    for fi in order:
        tri = F[fi]
        alpha, glow = A[fi]
        x, y, z = X[tri], Y[tri], Z[tri]
        x0, x1 = max(int(math.floor(x.min())), 0), min(int(math.ceil(x.max())), size - 1)
        y0, y1 = max(int(math.floor(y.min())), 0), min(int(math.ceil(y.max())), size - 1)
        if x1 < x0 or y1 < y0:
            continue
        d = (y[1] - y[2]) * (x[0] - x[2]) + (x[2] - x[1]) * (y[0] - y[2])
        if abs(d) < 1e-9:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        w0 = ((y[1] - y[2]) * (gx - x[2]) + (x[2] - x[1]) * (gy - y[2])) / d
        w1 = ((y[2] - y[0]) * (gx - x[2]) + (x[0] - x[2]) * (gy - y[2])) / d
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        zz = w0 * z[0] + w1 * z[1] + w2 * z[2]
        sub = zb[y0:y1 + 1, x0:x1 + 1]
        mask = inside & (zz > sub)
        if not mask.any():
            continue
        n = w0[..., None] * Nn[tri[0]] + w1[..., None] * Nn[tri[1]] + w2[..., None] * Nn[tri[2]]
        n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-9)
        col = w0[..., None] * C[tri[0]] + w1[..., None] * C[tri[1]] + w2[..., None] * C[tri[2]]
        if glow:
            shade = 0.9 + 0.1 * np.clip(n @ L, 0, 1)
        else:
            shade = 0.55 + 0.5 * np.clip(n @ L, 0, 1) + 0.08 * np.clip(n[..., 1], -1, 1)
        px = np.clip(col * shade[..., None], 0, 1)
        tile = img[y0:y1 + 1, x0:x1 + 1]
        if alpha < 1:
            tile[mask] = tile[mask] * (1 - alpha) + px[mask] * alpha
        else:
            tile[mask] = px[mask]
            sub[mask] = zz[mask]
    return Image.fromarray((img * 255).astype(np.uint8))


def sheet(models, path, cols=6, size=300):
    names = list(models)
    rows = (len(names) + cols - 1) // cols
    im = Image.new("RGB", (cols * size, rows * (size + 22)), (255, 255, 255))
    dr = ImageDraw.Draw(im)
    for i, n in enumerate(names):
        t = render(models[n], size)
        x, y = (i % cols) * size, (i // cols) * (size + 22)
        im.paste(t, (x, y))
        dr.text((x + 6, y + size + 4), n, fill=(42, 33, 64))
    im.save(path)
