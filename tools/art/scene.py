import sys, math
sys.path.insert(0, "/home/claude/roblox-test/tools/models")
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import build, render
from meshlib import hexc

reg = build.registry()

def nodes_of(name, x=0, y=0, z=0, s=1.0, yaw=0):
    nodes, tris, size, *_ = build.make(name, reg[name])
    out = {}
    for k, m in nodes.items():
        if s != 1.0:
            m.scale(s)
        if yaw:
            m.rot("y", yaw)
        m.move(x, y, z)
        out[k] = m
    return out

def scene(items):
    allnodes = {}
    for i, it in enumerate(items):
        for k, m in nodes_of(*it[0:1], **it[1]).items():
            allnodes[f"{k}_k{i}"] = m
    return allnodes

def shot(nodes, size, yaw, pitch, out):
    render.BG = np.array([1.0, 0.0, 1.0])  # маркер фона
    img = render.render(nodes, size, yaw, pitch).convert("RGB")
    a = np.asarray(img).astype(float)
    mask = (a[..., 0] > 250) & (a[..., 1] < 5) & (a[..., 2] > 250)
    img.save(out)
    np.save(out + ".mask.npy", mask)

if __name__ == "__main__":
    which = sys.argv[1]
    size = int(sys.argv[2])
    if which == "icon":
        items = [
            ("chestPedestal", dict()),
            ("chest", dict(y=4.75)),
            ("chestLid", dict(y=8.25, z=3.5)),
            ("art_l_titan", dict(x=-8.5, y=0, z=-9, s=1.55, yaw=20)),
            ("art_e_dragon", dict(x=8.5, y=0.3, z=-9, s=1.7, yaw=-25)),
            ("art_r_fox", dict(x=-1.5, y=0, z=-14, s=1.9, yaw=5)),
        ]
    else:
        items = [
            ("chestPedestal", dict()),
            ("chest", dict(y=4.75)),
            ("chestLid", dict(y=8.25, z=3.5)),
            ("art_l_titan", dict(x=-9, z=-9, s=1.5, yaw=20)),
            ("art_e_dragon", dict(x=9, y=0.3, z=-9, s=1.6, yaw=-25)),
            ("art_r_fox", dict(x=-2, z=-14, s=1.8, yaw=5)),
            ("art_x_rift", dict(x=3.5, z=-14, s=1.2, yaw=-10)),
            ("art_e_phoenix", dict(x=-19, z=-4, s=1.4, yaw=35)),
            ("art_l_whale", dict(x=20, z=-3, s=1.1, yaw=-35)),
            ("art_r_owl", dict(x=-14, z=-14, s=1.6, yaw=20)),
            ("art_c_drop", dict(x=14, z=-15, s=2.6, yaw=-15)),
        ]
    shot(scene(items), size, -12 if which == "thumb" else -18, 14 if which == "thumb" else 18, f"/tmp/art/{which}_raw.png")
    print("ok")
