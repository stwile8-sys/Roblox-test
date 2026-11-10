#!/usr/bin/env python3
"""Генерирует все модели в tools/models/out/*.glb и manifest.json (размеры, треугольники, sha256).

Запуск: python3 tools/models/build.py [имя …] [--preview]
  --preview — дополнительно рисует контактный лист tools/models/preview.png (нужен Pillow).
"""
import hashlib
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from meshlib import write_glb  # noqa: E402
import props  # noqa: E402

try:
    import creatures  # noqa: E402
except ImportError:  # существа — необязательная часть
    creatures = None

OUT = os.path.join(HERE, "out")


def registry():
    reg = dict(props.MODELS)
    if creatures:
        reg.update(creatures.MODELS)
    return reg


def make(name, entry):
    fn, budget, desc = entry
    nodes = fn().nodes()
    lo = np.min([m.V.min(axis=0) for m in nodes.values()], axis=0)
    hi = np.max([m.V.max(axis=0) for m in nodes.values()], axis=0)
    # точка опоры — низ по центру габарита
    shift = -np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    for m in nodes.values():
        m.move(*shift)
    tris = sum(m.tris for m in nodes.values())
    size = hi - lo
    return nodes, tris, size, budget, desc


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    preview = "--preview" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    reg = registry()
    names = args or list(reg)
    mpath = os.path.join(OUT, "manifest.json")
    manifest = {}
    if args and os.path.isfile(mpath):
        manifest = json.load(open(mpath, encoding="utf-8"))
    built = {}
    bad = 0
    for name in names:
        nodes, tris, size, budget, desc = make(name, reg[name])
        path = os.path.join(OUT, name + ".glb")
        write_glb(path, nodes)
        data = open(path, "rb").read()
        manifest[name] = {
            "file": name + ".glb", "sha256": hashlib.sha256(data).hexdigest(), "tris": tris, "budget": budget,
            "size": [round(float(x), 2) for x in size], "nodes": sorted(nodes), "desc": desc,
        }
        flag = "" if tris <= budget else "  <-- ПРЕВЫШЕН БЮДЖЕТ"
        bad += tris > budget
        print(f"{name:16s} {tris:5d}/{budget} тр.  {size[0]:6.1f} × {size[1]:5.1f} × {size[2]:6.1f}  {len(data) // 1024:4d} КБ{flag}")
        built[name] = nodes
    manifest = {k: manifest[k] for k in reg if k in manifest}
    with open(mpath, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
        f.write("\n")
    if preview:
        import render
        render.sheet(built, os.path.join(HERE, "preview.png"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
