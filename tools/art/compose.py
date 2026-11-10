import sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FONT = "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf"
INK = (42, 33, 64)

def bg(w, h, top=(70, 190, 255), bot=(190, 240, 255)):
    t = np.linspace(0, 1, h)[:, None, None]
    a = np.array(top)[None, None, :] * (1 - t) + np.array(bot)[None, None, :] * t
    return Image.fromarray(np.repeat(a, w, axis=1).astype(np.uint8)).convert("RGBA")

def rays(img, cx, cy, n=14, alpha=40, r=2000):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for i in range(n):
        a0 = i * 2 * math.pi / n
        a1 = a0 + math.pi / n * 0.55
        d.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=(255, 255, 255, alpha))
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    R = int(min(img.size) * 0.38)
    gd.ellipse((cx - R, cy - R, cx + R, cy + R), fill=(255, 245, 200, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(R * 0.45))
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(3)))
    img.alpha_composite(glow)

def cutout(raw, mask):
    im = Image.open(raw).convert("RGBA")
    m = np.load(mask)
    a = np.asarray(im).copy()
    a[m] = (0, 0, 0, 0)
    out = Image.fromarray(a)
    # контурная тень под моделью
    return out

def outlined_text(img, xy, text, size, fill=(255, 210, 63), stroke=None, anchor="mm", sw=None, grad=True):
    f = ImageFont.truetype(FONT, size)
    sw = sw or max(4, size // 9)
    d = ImageDraw.Draw(img)
    # тень
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((xy[0], xy[1] + size * 0.08), text, font=f, fill=(20, 12, 40, 150), anchor=anchor, stroke_width=sw, stroke_fill=(20, 12, 40, 150))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(size * 0.04)))
    d.text(xy, text, font=f, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=stroke or INK)
    if grad:
        # светлый верх у букв
        lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(lay).text(xy, text, font=f, fill=(255, 255, 255, 255), anchor=anchor)
        bbox = lay.getbbox()
        if bbox:
            h = bbox[3] - bbox[1]
            g = np.zeros((img.size[1], img.size[0]), np.uint8)
            for yy in range(bbox[1], bbox[3]):
                v = max(0.0, 1 - (yy - bbox[1]) / (h * 0.55))
                g[yy, :] = int(110 * v)
            la = np.asarray(lay).copy()
            la[..., 3] = (la[..., 3].astype(int) * g // 255).astype(np.uint8)
            img.alpha_composite(Image.fromarray(la))

def icon():
    W = 1024
    img = bg(W, W)
    rays(img, W // 2, int(W * 0.58), n=16, alpha=46)
    sc = cutout("icon_raw.png", "icon_raw.png.mask.npy").resize((int(W * 1.0), int(W * 1.0)), Image.LANCZOS)
    img.alpha_composite(sc, (0, int(W * 0.12)))
    outlined_text(img, (W // 2, int(W * 0.12)), "CHRONO", 170)
    outlined_text(img, (W // 2, int(W * 0.27)), "HEIST", 190, fill=(255, 255, 255))
    img.convert("RGB").resize((512, 512), Image.LANCZOS).save("icon_512.png")

def thumb(lang):
    W, H = 1920, 1080
    img = bg(W, H)
    rays(img, W // 2, int(H * 0.62), n=18, alpha=40)
    sc = cutout("thumb_raw.png", "thumb_raw.png.mask.npy")
    s = W * 0.98 / sc.size[0]
    sc = sc.resize((int(sc.size[0] * s), int(sc.size[1] * s)), Image.LANCZOS)
    img.alpha_composite(sc, ((W - sc.size[0]) // 2, int(H * 0.56) - sc.size[1] // 2))
    outlined_text(img, (W // 2, 120), "CHRONO HEIST TYCOON", 132)
    tag = "Укради. Защити. Разбогатей." if lang == "ru" else "Steal. Defend. Get rich."
    f = ImageFont.truetype(FONT, 64)
    # подложка-пилюля под слоганом
    d = ImageDraw.Draw(img)
    tw = d.textlength(tag, font=f)
    pad = 40
    box = (W // 2 - tw / 2 - pad, H - 150, W // 2 + tw / 2 + pad, H - 50)
    pill = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(pill).rounded_rectangle(box, radius=50, fill=(35, 26, 59, 225))
    img.alpha_composite(pill)
    d.text((W // 2, H - 100), tag, font=f, fill=(255, 255, 255), anchor="mm")
    img.convert("RGB").save(f"thumb_{lang}.png")

if __name__ == "__main__":
    if sys.argv[1] == "icon":
        icon()
    else:
        thumb("ru")
        thumb("en")
    print("ok")
