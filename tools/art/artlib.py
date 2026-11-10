"""Рендер и вёрстка картинок для страницы игры: модели из tools/models → спрайты → композиция (numpy + Pillow)."""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "models"))

import build  # noqa: E402
from meshlib import Mesh, hexc, merge  # noqa: E402

FONT = "/usr/share/fonts/opentype/inter/InterDisplay-BlackItalic.otf"
DARK = (42, 33, 64)
REG = build.registry()
_cache = {}


def model(name):
    """Узлы модели (копия), опора в нуле."""
    if name not in _cache:
        _cache[name] = build.make(name, REG[name])[0]
    return {k: m.copy() for k, m in _cache[name].items()}


def T(nodes, s=1.0, yaw=0.0, pos=(0, 0, 0), rx=0.0, rz=0.0):
    out = {}
    for k, m in nodes.items():
        m = m.copy()
        if s != 1.0:
            m.scale(s)
        if rx:
            m.rot("x", rx)
        if rz:
            m.rot("z", rz)
        if yaw:
            m.rot("y", yaw)
        out[k] = m.move(*pos)
    return out


def join(*parts):
    acc = {}
    for p in parts:
        for k, m in p.items():
            acc.setdefault(k, []).append(m)
    return {k: merge(v) for k, v in acc.items()}


def shot(nodes, px, yaw=-28, pitch=18, ss=2, outline=0.014, bloom=True, tint=None):
    """Рендер узлов в RGBA-спрайт (большая сторона ≈ px), с тёмным контуром и свечением Glow-узлов."""
    V, N, C, F, A = [], [], [], [], []
    off = 0
    for name, m in nodes.items():
        c = m.C.copy()
        alpha, glow = 1.0, False
        parts = name.split("_")
        if parts[0] == "Glow":
            glow = True
            c = np.tile(hexc(parts[1]), (len(c), 1)) * 0.7 + c * 0.3
            for p in parts[2:]:
                if p.startswith("T"):
                    alpha = 1 - int(p[1:]) / 100
        elif tint and name in tint:
            c = c * hexc(tint[name])
        V.append(m.V); N.append(m.N); C.append(c); F.append(m.F + off)
        A += [(alpha, glow)] * len(m.F)
        off += len(m.V)
    V, N, C, F = np.vstack(V), np.vstack(N), np.vstack(C), np.vstack(F)
    ya, pa = math.radians(yaw), math.radians(-pitch)
    Ry = np.array([[math.cos(ya), 0, math.sin(ya)], [0, 1, 0], [-math.sin(ya), 0, math.cos(ya)]])
    Rx = np.array([[1, 0, 0], [0, math.cos(pa), -math.sin(pa)], [0, math.sin(pa), math.cos(pa)]])
    R = Rx @ Ry
    P = V @ R.T
    Nn = N @ R.T
    P[:, [0, 2]] *= -1; Nn[:, [0, 2]] *= -1
    lo, hi = P.min(axis=0), P.max(axis=0)
    S = px * ss
    s = S / max(hi[0] - lo[0], hi[1] - lo[1])
    pad = int(S * 0.08) + 4
    w, h = int((hi[0] - lo[0]) * s) + 2 * pad, int((hi[1] - lo[1]) * s) + 2 * pad
    X = (P[:, 0] - lo[0]) * s + pad
    Y = h - ((P[:, 1] - lo[1]) * s + pad)
    Z = P[:, 2]
    L = np.array([-0.4, 0.75, 0.55]); L /= np.linalg.norm(L)
    Hh = L + np.array([0, 0, 1.0]); Hh /= np.linalg.norm(Hh)
    img = np.zeros((h, w, 3)); al = np.zeros((h, w)); gl = np.zeros((h, w, 3))
    zb = np.full((h, w), -1e9)
    order = np.argsort([a[0] < 1 for a in A], kind="stable")
    for fi in order:
        tri = F[fi]
        alpha, glow = A[fi]
        x, y, z = X[tri], Y[tri], Z[tri]
        x0, x1 = max(int(x.min()), 0), min(int(x.max()) + 1, w - 1)
        y0, y1 = max(int(y.min()), 0), min(int(y.max()) + 1, h - 1)
        d = (y[1] - y[2]) * (x[0] - x[2]) + (x[2] - x[1]) * (y[0] - y[2])
        if x1 < x0 or y1 < y0 or abs(d) < 1e-9:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        w0 = ((y[1] - y[2]) * (gx - x[2]) + (x[2] - x[1]) * (gy - y[2])) / d
        w1 = ((y[2] - y[0]) * (gx - x[2]) + (x[0] - x[2]) * (gy - y[2])) / d
        w2 = 1 - w0 - w1
        zz = w0 * z[0] + w1 * z[1] + w2 * z[2]
        sub = zb[y0:y1 + 1, x0:x1 + 1]
        mask = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4) & (zz > sub)
        if not mask.any():
            continue
        n = w0[..., None] * Nn[tri[0]] + w1[..., None] * Nn[tri[1]] + w2[..., None] * Nn[tri[2]]
        n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-9)
        col = w0[..., None] * C[tri[0]] + w1[..., None] * C[tri[1]] + w2[..., None] * C[tri[2]]
        if glow:
            px_ = np.clip(col * (0.95 + 0.15 * np.clip(n @ L, 0, 1))[..., None], 0, 1)
        else:
            ndl = np.clip(n @ L, 0, 1)
            shade = 0.6 + 0.48 * ndl + 0.07 * n[..., 1]
            spec = np.clip(n @ Hh, 0, 1) ** 28 * 0.22
            rim = np.clip(1 - np.abs(n[..., 2]), 0, 1) ** 3 * 0.12
            px_ = np.clip(col * shade[..., None] + (spec + rim)[..., None], 0, 1)
        ti, ta, tg = img[y0:y1 + 1, x0:x1 + 1], al[y0:y1 + 1, x0:x1 + 1], gl[y0:y1 + 1, x0:x1 + 1]
        if alpha < 1:
            ti[mask] = ti[mask] * (1 - alpha) + px_[mask] * alpha
            ta[mask] = np.maximum(ta[mask], alpha)
            tg[mask] = np.maximum(tg[mask], px_[mask] * alpha * 0.8)
        else:
            ti[mask] = px_[mask]; ta[mask] = 1.0; sub[mask] = zz[mask]
            tg[mask] = px_[mask] if glow else 0.0
    rgba = np.dstack([img, al])
    im = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA").resize((w // ss, h // ss), Image.LANCZOS)
    glow_im = Image.fromarray((np.clip(gl, 0, 1) * 255).astype(np.uint8), "RGB").resize((w // ss, h // ss), Image.LANCZOS)
    a = im.getchannel("A")
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    if outline:
        r = max(2, int(px * outline))
        big = a.filter(ImageFilter.MaxFilter(2 * r + 1)).filter(ImageFilter.GaussianBlur(0.8))
        out.paste(Image.new("RGBA", im.size, DARK + (255,)), (0, 0), big)
    out.alpha_composite(im)
    if bloom:
        b = glow_im.filter(ImageFilter.GaussianBlur(max(2, px * 0.03)))
        halo = Image.merge("RGBA", (*b.split(), b.convert("L").point(lambda v: min(255, int(v * 1.6)))))
        base = Image.new("RGBA", im.size, (0, 0, 0, 0))
        base.alpha_composite(halo)
        base.alpha_composite(out)
        rgb = ImageChops.add(base.convert("RGB"), b.point(lambda v: int(v * 0.35)))
        out = Image.merge("RGBA", (*rgb.split(), base.getchannel("A")))
    return out


# ---------- холст ----------
def gradient(w, h, stops):
    """Вертикальный градиент: stops = [(t, '#hex'), …]."""
    ys = np.linspace(0, 1, h)
    arr = np.zeros((h, 3))
    for (t0, c0), (t1, c1) in zip(stops[:-1], stops[1:]):
        m = (ys >= t0) & (ys <= t1)
        k = ((ys[m] - t0) / max(t1 - t0, 1e-9))[:, None]
        arr[m] = hexc(c0) * (1 - k) + hexc(c1) * k
    return Image.fromarray((np.tile(arr[:, None, :], (1, w, 1)) * 255).astype(np.uint8), "RGB").convert("RGBA")


def radial(w, h, center, radius, inner, outer_alpha=0):
    """Мягкое круглое пятно цвета inner (RGBA-слой)."""
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.hypot(xx - center[0], yy - center[1]) / radius
    a = np.clip(1 - d, 0, 1) ** 1.6
    c = hexc(inner)
    arr = np.dstack([np.full((h, w), c[0]), np.full((h, w), c[1]), np.full((h, w), c[2]), a * (1 - outer_alpha)])
    return Image.fromarray((arr * 255).astype(np.uint8), "RGBA")


def rays(w, h, center, n=18, color=(255, 255, 255), alpha=38, phase=0.0):
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    R = math.hypot(w, h)
    for i in range(n):
        a0 = 2 * math.pi * (i + phase) / n
        a1 = a0 + math.pi / n
        d.polygon([center, (center[0] + R * math.cos(a0), center[1] + R * math.sin(a0)),
                   (center[0] + R * math.cos(a1), center[1] + R * math.sin(a1))], fill=color + (alpha,))
    return layer.filter(ImageFilter.GaussianBlur(2))


def cloud(canvas, x, y, s, alpha=235):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for dx, dy, r in ((0, 0, 1.0), (-0.9, 0.25, 0.7), (0.95, 0.2, 0.75), (0.4, -0.45, 0.7), (-0.4, -0.3, 0.6), (1.7, 0.4, 0.45), (-1.6, 0.42, 0.42)):
        d.ellipse([x + (dx - r) * s, y + (dy - r) * s, x + (dx + r) * s, y + (dy + r) * s], fill=(255, 255, 255, alpha))
    d.rectangle([x - 1.9 * s, y + 0.42 * s, x + 2.0 * s, y + 1.2 * s], fill=(0, 0, 0, 0))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(s * 0.05)))


def sparkle(canvas, x, y, s, color=(255, 255, 255, 255)):
    d = ImageDraw.Draw(canvas)
    k = s * 0.22
    d.polygon([(x, y - s), (x + k, y - k), (x + s, y), (x + k, y + k), (x, y + s), (x - k, y + k), (x - s, y), (x - k, y - k)], fill=color)


def put(canvas, sprite, cx, base_y, height=None, shadow=True, flip=False, rot=0.0, anchor="bottom"):
    """Ставит спрайт: cx — центр по X, base_y — низ (или центр при anchor='center')."""
    if height:
        k = height / sprite.height
        sprite = sprite.resize((max(1, int(sprite.width * k)), max(1, int(sprite.height * k))), Image.LANCZOS)
    if flip:
        sprite = sprite.transpose(Image.FLIP_LEFT_RIGHT)
    if rot:
        sprite = sprite.rotate(rot, expand=True, resample=Image.BICUBIC)
    x = int(cx - sprite.width / 2)
    y = int(base_y - (sprite.height if anchor == "bottom" else sprite.height / 2))
    if shadow:
        sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        dd = ImageDraw.Draw(sh)
        ww = sprite.width * 0.36
        by = y + sprite.height * (0.93 if anchor == "bottom" else 1.0)
        dd.ellipse([cx - ww, by - ww * 0.2, cx + ww, by + ww * 0.2], fill=(42, 33, 64, 90))
        canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(max(2, ww * 0.12))))
    canvas.alpha_composite(sprite, (x, y)) if 0 <= x and 0 <= y and x + sprite.width <= canvas.width and y + sprite.height <= canvas.height else _safe(canvas, sprite, x, y)


def _safe(canvas, sprite, x, y):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(sprite, (x, y))
    canvas.alpha_composite(layer)


def text(canvas, s, cx, cy, size, max_w=None, top="#FFF6B0", bottom="#FFB347", stroke=None, rot=0.0, white_edge=True):
    """Крупная надпись: градиентная заливка, тёмная обводка, тень. Центр в (cx, cy)."""
    font = ImageFont.truetype(FONT, size)
    if max_w:
        while font.getlength(s) > max_w and size > 20:
            size -= 4
            font = ImageFont.truetype(FONT, size)
    sw = stroke or max(4, size // 9)
    l, t, r, b = font.getbbox(s, stroke_width=sw)
    pad = sw * 3
    W, H = r - l + 2 * pad, b - t + 2 * pad
    o = (pad - l, pad - t)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((o[0], o[1] + sw * 0.9), s, font=font, fill=DARK + (255,), stroke_width=sw, stroke_fill=DARK + (255,))  # тень-подложка
    d.text(o, s, font=font, fill=DARK + (255,), stroke_width=sw, stroke_fill=DARK + (255,))
    if white_edge:
        d.text(o, s, font=font, fill=(255, 255, 255, 255), stroke_width=max(1, sw // 4), stroke_fill=(255, 255, 255, 255))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).text(o, s, font=font, fill=255)
    g = gradient(W, H, [(0, top), (pad / H, top), (1 - pad / H, bottom), (1, bottom)])
    layer.paste(g, (0, 0), mask)
    # блик по верхней трети букв
    hi = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hi).rectangle([0, 0, W, int(pad + (H - 2 * pad) * 0.42)], fill=70)
    layer.paste(Image.new("RGBA", (W, H), (255, 255, 255, 255)), (0, 0), ImageChops.multiply(mask, hi))
    if rot:
        layer = layer.rotate(rot, expand=True, resample=Image.BICUBIC)
    _safe(canvas, layer, int(cx - layer.width / 2), int(cy - layer.height / 2))
    return layer.size


def ribbon(canvas, s, cx, cy, size, max_w=None, fill="#7B2FF7", fg=(255, 255, 255, 255), rot=0.0):
    """Слоган на плашке."""
    font = ImageFont.truetype(FONT, size)
    if max_w:
        while font.getlength(s) > max_w - size * 1.6 and size > 16:
            size -= 2
            font = ImageFont.truetype(FONT, size)
    l, t, r, b = font.getbbox(s)
    px_, py = int(size * 0.7), int(size * 0.38)
    W, H = r - l + 2 * px_ + 16, b - t + 2 * py + 24
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rad = (H - 24) // 2
    d.rounded_rectangle([4, 12, W - 4, H - 4], rad, fill=DARK + (255,))
    d.rounded_rectangle([8, 8, W - 8, H - 16], rad, fill=tuple(int(v * 255) for v in hexc(fill)) + (255,), outline=DARK + (255,), width=5)
    d.text((8 + px_ - l, 8 + py - t - 2), s, font=font, fill=fg)
    if rot:
        layer = layer.rotate(rot, expand=True, resample=Image.BICUBIC)
    _safe(canvas, layer, int(cx - layer.width / 2), int(cy - layer.height / 2))


def finish(canvas, path, vignette=0.22, sat=1.12):
    w, h = canvas.size
    img = canvas.convert("RGB")
    img = ImageEnhance.Color(img).enhance(sat)
    img = ImageEnhance.Contrast(img).enhance(1.04)
    if vignette:
        yy, xx = np.mgrid[0:h, 0:w]
        d = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2))
        v = 1 - vignette * np.clip(d - 0.75, 0, 1) ** 1.5 * 2
        img = Image.fromarray((np.asarray(img) * v[..., None]).clip(0, 255).astype(np.uint8))
    img.save(path, optimize=True)
    return img
