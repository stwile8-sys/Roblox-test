#!/usr/bin/env python3
"""Загрузка 3D-моделей Chrono Heist Tycoon в Roblox через Open Cloud (только stdlib).

Запускается в GitHub Actions (.github/workflows/models.yml) при пуше в ветку models. Идемпотентен:
  * состояние — tools/models/state.json (workflow коммитит его обратно);
  * модель пропускается, если файл с тем же sha256 уже загружен;
  * если файл изменился — сначала пробуем обновить тот же ассет (ID сохраняется), иначе создаём новый.

После загрузки пишет:
  src/shared/Config/Models.luau      — { имя = assetId }
  src/shared/Config/ModelSizes.luau  — { имя = Vector3 габарит } (ModelLib по нему выравнивает масштаб)
  docs/MODELS.md                     — таблица моделей
  tools/models/report.md             — что загружено и какие были ошибки

Форматы Assets API для assetType Model (create.roblox.com/docs/cloud/guides/usage-assets):
  .fbx (model/fbx), .gltf (model/gltf+json), .glb (model/gltf-binary), .rbxm/.rbxmx. Здесь — .glb.

Ключи: ROBLOX_API_KEY (обязательно), CREATOR_USER_ID. Флаг --write-only — только переписать файлы без сети.
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "out")
STATE_PATH = os.path.join(HERE, "state.json")
REPORT_PATH = os.path.join(HERE, "report.md")
LUAU_IDS = os.path.join(ROOT, "src", "shared", "Config", "Models.luau")
LUAU_SIZES = os.path.join(ROOT, "src", "shared", "Config", "ModelSizes.luau")
LUAU_PIVOTS = os.path.join(ROOT, "src", "shared", "Config", "ModelPivots.luau")
DOC_PATH = os.path.join(ROOT, "docs", "MODELS.md")

API = "https://apis.roblox.com"
KEY = os.environ.get("ROBLOX_API_KEY", "").strip()
USER_ID = os.environ.get("CREATOR_USER_ID", "1124897065")
GAP = float(os.environ.get("UPLOAD_GAP", "1.5"))
MIME = "model/gltf-binary"

ERRORS = []
LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    LOG.append(s)
    print(s, flush=True)


def err(where, code, body):
    msg = f"[{where}] HTTP {code}: {str(body)[:600]}"
    ERRORS.append(msg)
    log("::error::" + msg.replace("\n", " "))


def http(method, url, body=None, ctype=None, retries=4):
    headers = {"x-api-key": KEY, "Accept": "application/json", "User-Agent": "chrono-heist-models/1.0"}
    if ctype:
        headers["Content-Type"] = ctype
    delay = 3.0
    code, text = 0, ""
    for attempt in range(retries + 1):
        req = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                code, text = r.status, r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            code, text = e.code, e.read().decode("utf-8", "replace")
        except Exception as e:  # сеть
            code, text = 0, f"{type(e).__name__}: {e}"
        if code in (0, 429, 500, 502, 503, 504) and attempt < retries:
            log(f"  {method} … -> {code}, повтор через {delay:.0f} с")
            time.sleep(delay)
            delay *= 2
            continue
        break
    try:
        data = json.loads(text) if text.strip() else None
    except ValueError:
        data = None
    return code, text, data


def multipart(fields, files=()):
    b = "----chm" + uuid.uuid4().hex
    out = bytearray()
    for name, val in fields:
        out += f"--{b}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n".encode()
        out += str(val).encode("utf-8") + b"\r\n"
    for name, fname, mime, data in files:
        out += (f"--{b}\r\nContent-Disposition: form-data; name=\"{name}\"; filename=\"{fname}\"\r\n"
                f"Content-Type: {mime}\r\n\r\n").encode()
        out += data + b"\r\n"
    out += f"--{b}--\r\n".encode()
    return bytes(out), f"multipart/form-data; boundary={b}"


def load_json(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def save_state(state):
    with open(STATE_PATH, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")


def poll(op_id, timeout=150):
    end = time.time() + timeout
    delay = 2.0
    while True:
        c, t, d = http("GET", f"{API}/assets/v1/operations/{op_id}")
        if c != 200 or d is None:
            return None, f"HTTP {c}: {t[:500]}"
        if d.get("done"):
            if d.get("response"):
                return d["response"], None
            return None, "operation error: " + json.dumps(d.get("error") or d, ensure_ascii=False)[:600]
        if time.time() > end:
            return None, "pending"
        time.sleep(delay)
        delay = min(delay * 1.4, 8)


def finish(st, resp):
    st["assetId"] = int(resp["assetId"])
    st["moderation"] = (resp.get("moderationResult") or {}).get("moderationState")
    st.pop("operationId", None)


def send(method, url, req, fname, data):
    body, ct = multipart([("request", json.dumps(req))], [("fileContent", fname, MIME, data)])
    c, t, d = http(method, url, body, ct, retries=3)
    if c != 200 or not d:
        return None, None, (c, t)
    op_id = d.get("operationId") or (d.get("path") or "").split("/")[-1]
    if d.get("done") and d.get("response"):
        return d["response"], op_id, None
    resp, e = poll(op_id)
    if resp:
        return resp, op_id, None
    return None, op_id, ("-", e)


def upload_all(state, manifest):
    creator = {"userId": USER_ID}
    stop = None
    for name, info in manifest.items():
        path = os.path.join(OUT, info["file"])
        with open(path, "rb") as f:
            data = f.read()
        sha = hashlib.sha256(data).hexdigest()
        st = state.get(name) or {}
        if st.get("sha256") == sha and st.get("assetId"):
            log(f"  {name}: уже загружен {st['assetId']}")
            continue
        if st.get("sha256") == sha and st.get("operationId"):
            resp, e = poll(st["operationId"], timeout=40)
            if resp and resp.get("assetId"):
                finish(st, resp)
                state[name] = st
                log(f"  {name}: дождались операции -> {st['assetId']}")
                save_state(state)
                continue
        if stop:
            log(f"  {name}: пропущен ({stop})")
            continue
        time.sleep(GAP)
        resp = None
        if st.get("assetId"):  # файл изменился — обновляем тот же ассет, чтобы ID не менялся
            resp, op_id, e = send("PATCH", f"{API}/assets/v1/assets/{st['assetId']}", {"assetId": str(st["assetId"])}, info["file"], data)
            if resp and resp.get("assetId"):
                st["sha256"] = sha
                finish(st, resp)
                state[name] = st
                log(f"  {name}: обновлён {st['assetId']} ({info['tris']} тр.)")
                save_state(state)
                continue
            log(f"  {name}: обновить {st['assetId']} не вышло ({e}), создаю новый ассет")
        req = {"assetType": "Model", "displayName": f"CHT {name}"[:50],
               "description": f"Chrono Heist Tycoon: {info['desc']}"[:900], "creationContext": {"creator": creator}}
        resp, op_id, e = send("POST", f"{API}/assets/v1/assets", req, info["file"], data)
        if resp and resp.get("assetId"):
            st = {"sha256": sha}
            finish(st, resp)
            state[name] = st
            log(f"  {name}: загружен {st['assetId']} ({info['tris']} тр., moderation={st['moderation']})")
        elif e and e[1] == "pending":
            state[name] = dict(st, sha256=sha, operationId=op_id) if not st.get("assetId") else st
            log(f"  {name}: операция {op_id} ещё идёт — заберём при следующем запуске")
        else:
            err(f"upload:{name}", e[0], e[1])
            low = str(e[1]).lower()
            if e[0] in (401, 403):
                stop = f"Open Cloud отвечает {e[0]} — ключ/права/модерация аккаунта"
            elif "quota" in low or "limit" in low and "exceed" in low:
                stop = "исчерпана квота загрузок"
        save_state(state)


# ---------- генерация файлов ----------
def luau_key(k):
    return k if k.isidentifier() else f'["{k}"]'


def write_outputs(state, manifest):
    ids = {n: int((state.get(n) or {}).get("assetId") or 0) for n in manifest}
    lines = ["--!strict", "-- Asset ID 3D-моделей. Файл пишет пайплайн tools/models/upload.py (ветка models) — руками не править.",
             "-- 0 = модель ещё не загружена: ModelLib.get вернёт nil, игра строит старый вариант из деталей.", "return {"]
    lines += [f"\t{luau_key(n)} = {i}," for n, i in ids.items()]
    lines += ["} :: { [string]: number }", ""]
    with open(LUAU_IDS, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    lines = ["--!strict", "-- Габариты моделей в стадах (X, Y, Z). Пишет tools/models/upload.py — руками не править.",
             "-- ModelLib по ним приводит масштаб импортированного меша и ставит точку опоры в «низ по центру».", "return {"]
    lines += [f"\t{luau_key(n)} = Vector3.new({m['size'][0]}, {m['size'][1]}, {m['size'][2]})," for n, m in manifest.items()]
    lines += ["} :: { [string]: Vector3 }", ""]
    with open(LUAU_SIZES, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    lines = ["--!strict", "-- Смещение точки опоры от «низа по центру габарита» для моделей со своей опорой (стады).",
             "-- Пишет tools/models/upload.py — руками не править.", "return {"]
    lines += [f"\t{luau_key(n)} = Vector3.new({m['pivot'][0]}, {m['pivot'][1]}, {m['pivot'][2]})," for n, m in manifest.items() if m.get("pivot")]
    lines += ["} :: { [string]: Vector3 }", ""]
    with open(LUAU_PIVOTS, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    doc = [
        "# 3D-модели (ветка `models`)", "",
        "Модели генерируются кодом (`tools/models/*.py` → `tools/models/out/*.glb`) и загружаются в Roblox через Open Cloud",
        "(`.github/workflows/models.yml`, без Studio). Таблицу ниже переписывает `tools/models/upload.py`.", "",
        "- **Точка опоры** — низ по центру габарита: `model:PivotTo(cf)` ставит модель «на пол» в точке `cf`.",
        "  Исключения (своя опора, `Config/ModelPivots.luau`): `chestLid` — ось петель, `beltArc` — центр кольца.",
        "- **Ориентация** — перед смотрит на −Z (у ворот — ручки, у ящика — замок, у портала — проём). Y вверх.",
        "- **Размер** — X × Y × Z в стадах. `ModelLib` сам приводит масштаб к этим числам (`Config/ModelSizes.luau`).",
        "- **Узлы**: `Body` — цвета в вершинах; `Glow_RRGGBB[_Tnn]` — светящиеся части (ModelLib делает их Neon нужного цвета,",
        "  `Tnn` — прозрачность в %). Свет можно перекрасить: найти детали с именем `Glow_…` и сменить `Color`.",
        "- **Коллизии** выключены (`CanCollide/CanQuery/CanTouch = false`): модель — только вид, логика остаётся на старых невидимых деталях.",
        "- Острова: верх травы = точка опоры + высота Y. Конвейер: лента едет вдоль +X, верх ленты на 1.2 от опоры.",
        "  Мост — вдоль Z. Стены и ворота — вдоль X, толщина по Z.",
        "- Кольцевой конвейер: `beltArc` × 44, сегмент i — `PivotTo(center * CFrame.Angles(0, i * 2π/44, 0))`.",
        "- Клетка `cage`: прутья — детали `Bar1`…`Bar8` (у каждого прута две детали с одним именем: стержень и шар), `Base`, `Top`.", "",
        "```lua", "local ModelLib = require(script.Parent.World.ModelLib)",
        "local m = ModelLib.get(\"pedestal\") -- копия Model или nil (тогда строим старый вариант из деталей)",
        "if m then m:PivotTo(cf); m.Parent = parent end", "```", "",
        "| Имя | Asset ID | Размер X×Y×Z | Треуг. | Что это |", "|---|---|---|---|---|",
    ]
    for n, m in manifest.items():
        s = m["size"]
        doc.append(f"| `{n}` | {ids[n] or '— не загружено'} | {s[0]} × {s[1]} × {s[2]} | {m['tris']} | {m['desc']} |")
    doc.append("")
    with open(DOC_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(doc))
    return ids


def main():
    manifest = load_json(os.path.join(OUT, "manifest.json"), None)
    if not manifest:
        print("Нет tools/models/out/manifest.json — сначала python3 tools/models/build.py")
        return 1
    state = load_json(STATE_PATH, {})
    write_only = "--write-only" in sys.argv
    if not write_only:
        if not KEY:
            log("::error::Нет секрета ROBLOX_API_KEY")
            write_outputs(state, manifest)
            return 1
        log(f"=== модели: {len(manifest)} ===")
        try:
            upload_all(state, manifest)
        finally:
            save_state(state)
    ids = write_outputs(state, manifest)
    done = [n for n, i in ids.items() if i]
    miss = [n for n, i in ids.items() if not i]
    if not write_only:
        rep = ["# Отчёт загрузки моделей", "", f"Загружено: {len(done)} из {len(ids)}.", ""]
        rep += [f"- `{n}` = {ids[n]} (модерация: {(state.get(n) or {}).get('moderation')})" for n in done]
        if miss:
            rep += ["", "Не загружено: " + ", ".join(f"`{n}`" for n in miss)]
        if ERRORS:
            rep += ["", "## Ошибки", ""] + [f"- {e}" for e in ERRORS]
        with open(REPORT_PATH, "w", encoding="utf-8") as f:
            f.write("\n".join(rep) + "\n")
        log("=====MODELS-JSON-BEGIN=====")
        log(json.dumps({"models": ids, "errors": ERRORS}, ensure_ascii=False, indent=1))
        log("=====MODELS-JSON-END=====")
    return 0 if done or write_only else 1


if __name__ == "__main__":
    sys.exit(main())
