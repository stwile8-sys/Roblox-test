#!/usr/bin/env python3
"""Пайплайн ассетов Chrono Heist Tycoon через Roblox Open Cloud (только stdlib).

Запускается в GitHub Actions (.github/workflows/assets.yml). Идемпотентен:
  * состояние — tools/assets/state.json (workflow коммитит его обратно в ветку assets);
  * геймпассы и товары ищутся по имени среди уже существующих — дублей нет;
  * звуки пропускаются, если файл с тем же sha256 уже загружен.

Переменные окружения: ROBLOX_API_KEY (обязательно), UNIVERSE_ID, PLACE_ID, SERVER_SIZE.

Эндпоинты (create.roblox.com/docs/cloud/reference/features/*):
  GET   https://apis.roblox.com/cloud/v2/universes/{u}                         — владелец (user/group)
  POST  https://apis.roblox.com/assets/v1/assets                               — загрузка (multipart: request + fileContent)
  GET   https://apis.roblox.com/assets/v1/operations/{id}                      — статус загрузки
  GET   https://apis.roblox.com/game-passes/v1/universes/{u}/game-passes/creator
  POST  https://apis.roblox.com/game-passes/v1/universes/{u}/game-passes       — multipart
  PATCH https://apis.roblox.com/game-passes/v1/universes/{u}/game-passes/{id}  — multipart
  GET   https://apis.roblox.com/developer-products/v2/universes/{u}/developer-products/creator
  POST  https://apis.roblox.com/developer-products/v2/universes/{u}/developer-products
  PATCH https://apis.roblox.com/developer-products/v2/universes/{u}/developer-products/{id}
  PATCH https://apis.roblox.com/cloud/v2/universes/{u}/places/{p}?updateMask=serverSize
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))
STATE_PATH = os.path.join(HERE, "state.json")
ICONS_DIR = os.path.join(HERE, "icons")
SFX_DIR = os.path.join(ROOT, "tools", "sfx", "out")

API = "https://apis.roblox.com"
KEY = os.environ.get("ROBLOX_API_KEY", "").strip()
UNIVERSE = os.environ.get("UNIVERSE_ID", "1195242587")
PLACE = os.environ.get("PLACE_ID", "3327609598")
SERVER_SIZE = int(os.environ.get("SERVER_SIZE", "8"))

GAME_PASSES = [
    ("VIP", "VIP", 99, "VIP навсегда: +10% офлайн-дохода, золотой ник, ежедневный бонус"),
    ("AutoCollect", "Авто-сборщик", 199, "Авто-сборщик: доход собирается сам"),
    ("ScannerPlus", "Сканер+", 299, "Сканер+: 5 баз вместо 3 и скрытая личность вора"),
    ("SecondFloor", "Второй этаж", 499, "Второй этаж базы: +10 пьедесталов и второй конвейер"),
]

PRODUCTS = [
    ("Starter", "Стартовый набор", 49, "Стартовый набор: 500 Cash + редкий артефакт + скин"),
    ("Titan", "Титан-набор", 1999, "Титан-набор: скин ловушки «Чёрная дыра» + скин «Титан»"),
    ("Shards100", "100 Хроно-осколков", 49, "100 Хроно-осколков"),
    ("Shards550", "550 Хроно-осколков", 199, "550 Хроно-осколков"),
    ("Shards1500", "1500 Хроно-осколков", 449, "1500 Хроно-осколков"),
    ("Energy5", "Энергетик", 25, "Энергетик: +5 энергии"),
    ("BoostX2", "Доход x2 (15 мин)", 59, "x2 доход на 15 минут"),
    ("SeasonPass", "Хроно-пропуск", 999, "Хроно-пропуск сезона"),
]

# Порядок загрузки звуков: самые важные первыми (у аккаунта без верификации квота — 10 аудио в месяц).
SFX_ORDER = [
    "coin", "buy", "click", "steal", "caught", "escape", "hack", "wallBreak", "upgrade", "alarm",
    "pop", "whoosh", "trap", "rebirth", "voiceCommon", "voiceRare", "voiceEpic", "voiceLegendary", "voiceChrono",
]
AUDIO_GAP = float(os.environ.get("AUDIO_GAP", "6"))  # пауза между загрузками аудио, с
SFX_MIME = {".ogg": "audio/ogg", ".mp3": "audio/mpeg", ".wav": "audio/wav", ".flac": "audio/flac"}

ERRORS = []


def log(*a):
    print(*a, flush=True)


def err(where, code, body):
    msg = f"[{where}] HTTP {code}: {body[:1500] if isinstance(body, str) else body}"
    ERRORS.append(msg)
    log("::error::" + msg.replace("\n", " "))


# ---------- HTTP ----------
def http(method, url, body=None, ctype=None, retries=4):
    headers = {"x-api-key": KEY, "Accept": "application/json", "User-Agent": "chrono-heist-assets/1.0"}
    if ctype:
        headers["Content-Type"] = ctype
    delay = 2.0
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
            ra = None
            if code == 429:
                log(f"  {method} {url} -> 429, жду…")
            time.sleep(ra or delay)
            delay *= 2
            continue
        try:
            data = json.loads(text) if text.strip() else None
        except ValueError:
            data = None
        return code, text, data
    return code, text, None


def multipart(fields, files=()):
    """fields: [(name, str)], files: [(name, filename, mime, bytes)] -> (body, content_type)"""
    b = "----chb" + uuid.uuid4().hex
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


# иконки, которые надо перезалить у уже созданных товаров (один раз; отметка в state["iconsRefreshed"])
REFRESH_ICONS = {"BoostX2": "v2-moneybag"}


def icon_file(key):
    p = os.path.join(ICONS_DIR, key + ".png")
    if os.path.isfile(p):
        with open(p, "rb") as f:
            return [("imageFile", key + ".png", "image/png", f.read())]
    return []


# ---------- state ----------
def load_state():
    try:
        with open(STATE_PATH, encoding="utf-8") as f:
            s = json.load(f)
    except (OSError, ValueError):
        s = {}
    for k in ("sfx", "passes", "products"):
        s.setdefault(k, {})
    return s


def save_state(s):
    with open(STATE_PATH, "w", encoding="utf-8") as f:
        json.dump(s, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")


# ---------- шаги ----------
def get_creator(state):
    code, text, data = http("GET", f"{API}/cloud/v2/universes/{UNIVERSE}")
    if code == 200 and data:
        log(f"Universe: {data.get('displayName')!r} user={data.get('user')} group={data.get('group')}")
        if data.get("group"):
            state["creator"] = {"groupId": data["group"].split("/")[-1]}
        elif data.get("user"):
            state["creator"] = {"userId": data["user"].split("/")[-1]}
    else:
        err("universe", code, text)
        if code in (401, 403):
            # «User is moderated» / неверный ключ: дальше всё равно будет 403 — не долбим API зря
            raise SystemExit(f"Стоп: Open Cloud отвечает {code} уже на чтение universe: {text[:300]}")
    return state.get("creator")


def list_all(url, key):
    items, token = [], ""
    for _ in range(50):
        q = "?pageSize=50" + (f"&pageToken={urllib.parse.quote(token)}" if token else "")
        code, text, data = http("GET", url + q)
        if code != 200 or data is None:
            return None, code, text
        items += data.get(key) or []
        token = data.get("nextPageToken") or ""
        if not token:
            break
    return items, 200, ""


def price_of(item):
    pi = item.get("priceInformation") or {}
    return pi.get("defaultPriceInRobux", item.get("price"))


def sync_catalog(state, kind):
    if kind == "passes":
        base = f"{API}/game-passes/v1/universes/{UNIVERSE}/game-passes"
        list_key, id_key, items = "gamePasses", "gamePassId", GAME_PASSES
    else:
        base = f"{API}/developer-products/v2/universes/{UNIVERSE}/developer-products"
        list_key, id_key, items = "developerProducts", "productId", PRODUCTS
    log(f"\n=== {kind} ===")
    existing, code, text = list_all(base + "/creator", list_key)
    if existing is None:
        # без списка нельзя проверить дубли — ничего не создаём
        err(f"{kind}:list", code, text)
        log(f"  список недоступен — {kind} пропущены, чтобы не наделать дублей")
        return
    log(f"  уже есть: {len(existing)}")
    for e in existing:
        log(f"    {e.get(id_key)} {e.get('name')!r} price={price_of(e)} forSale={e.get('isForSale')} "
            f"icon={e.get('iconAssetId') or e.get('iconImageAssetId')}")
    by_name = {e.get("name"): e for e in existing}
    by_id = {str(e.get(id_key)): e for e in existing}

    for key, name, price, desc in items:
        cur = by_id.get(str(state[kind].get(key, ""))) or by_name.get(name)
        if cur:
            cid = cur.get(id_key)
            state[kind][key] = cid
            fields = []
            if cur.get("name") != name:
                fields.append(("name", name))
            if (cur.get("description") or "") != desc:
                fields.append(("description", desc))
            if price_of(cur) != price:
                fields.append(("price", price))
            if not cur.get("isForSale"):
                fields.append(("isForSale", "true"))
                if ("price", price) not in fields:
                    fields.append(("price", price))
            files = []
            ver = REFRESH_ICONS.get(key)
            done = state.setdefault("iconsRefreshed", {})
            if ver and done.get(key) != ver and icon_file(key):
                files = icon_file(key)
            if fields or files:
                body, ct = multipart(fields, files)
                c, t, _ = http("PATCH", f"{base}/{cid}", body, ct)
                if c in (200, 204):
                    log(f"  {key}: обновлён {cid} {[f[0] for f in fields]}{' + иконка' if files else ''}")
                    if files:
                        done[key] = ver
                else:
                    err(f"{kind}:update:{key}", c, t)
            else:
                log(f"  {key}: уже есть {cid}")
            continue
        fields = [("name", name), ("description", desc), ("price", price), ("isForSale", "true")]
        body, ct = multipart(fields, icon_file(key))
        c, t, d = http("POST", base, body, ct)
        if c in (200, 201) and d and d.get(id_key):
            state[kind][key] = d[id_key]
            log(f"  {key}: создан {d[id_key]}")
            continue
        if icon_file(key) and c == 400:
            # повтор без картинки — вдруг не понравилась иконка
            log(f"  {key}: HTTP {c} с иконкой ({t[:300]}), пробую без неё")
            body, ct = multipart(fields)
            c, t, d = http("POST", base, body, ct)
            if c in (200, 201) and d and d.get(id_key):
                state[kind][key] = d[id_key]
                log(f"  {key}: создан без иконки {d[id_key]}")
                continue
        err(f"{kind}:create:{key}", c, t)


def set_server_size(state):
    log("\n=== serverSize ===")
    url = f"{API}/cloud/v2/universes/{UNIVERSE}/places/{PLACE}?updateMask=serverSize"
    c, t, d = http("PATCH", url, json.dumps({"serverSize": SERVER_SIZE}).encode(), "application/json")
    if c == 200 and d:
        state["serverSize"] = d.get("serverSize")
        log(f"  serverSize = {d.get('serverSize')}")
        return d.get("serverSize")
    err("place:serverSize", c, t)
    return f"error {c}"


def poll_operation(op_id, timeout=90):
    end = time.time() + timeout
    delay = 1.5
    while True:
        c, t, d = http("GET", f"{API}/assets/v1/operations/{op_id}")
        if c != 200 or d is None:
            return None, f"HTTP {c}: {t[:800]}"
        if d.get("done"):
            if d.get("response"):
                return d["response"], None
            return None, "operation error: " + json.dumps(d.get("error") or d.get("status") or d, ensure_ascii=False)[:800]
        if time.time() > end:
            return None, "pending"
        time.sleep(delay)
        delay = min(delay * 1.5, 8)


def upload_sfx(state, creator):
    log("\n=== sfx ===")
    if not creator:
        err("sfx", "-", "нет creator (не удалось получить владельца universe)")
        return
    files = {}
    if os.path.isdir(SFX_DIR):
        for fn in os.listdir(SFX_DIR):
            k, ext = os.path.splitext(fn)
            if ext.lower() in SFX_MIME:
                files[k] = os.path.join(SFX_DIR, fn)
    order = [k for k in SFX_ORDER if k in files] + sorted(k for k in files if k not in SFX_ORDER)
    quota_hit = False
    for key in order:
        path = files[key]
        with open(path, "rb") as f:
            data = f.read()
        sha = hashlib.sha256(data).hexdigest()
        st = state["sfx"].get(key) or {}
        if st.get("sha256") == sha and st.get("assetId"):
            if st.get("moderation") != "Approved":
                c, t, d = http("GET", f"{API}/assets/v1/assets/{st['assetId']}?readMask=moderationResult")
                if c == 200 and d:
                    st["moderation"] = (d.get("moderationResult") or {}).get("moderationState", st.get("moderation"))
                else:
                    log(f"  {key}: не удалось узнать модерацию: HTTP {c} {t[:300]}")
            log(f"  {key}: уже загружен {st['assetId']} (moderation={st.get('moderation')})")
            continue
        if st.get("sha256") == sha and st.get("operationId"):
            resp, e = poll_operation(st["operationId"], timeout=30)
            if resp and resp.get("assetId"):
                st["assetId"] = int(resp["assetId"])
                st["moderation"] = (resp.get("moderationResult") or {}).get("moderationState")
                state["sfx"][key] = st
                log(f"  {key}: дождались операции -> {st['assetId']}")
                continue
            if e == "pending":
                log(f"  {key}: операция {st['operationId']} ещё идёт")
                continue
            log(f"  {key}: старая операция не удалась ({e}), загружаю заново")
        if quota_hit:
            log(f"  {key}: пропущен ({quota_hit})")
            continue
        time.sleep(AUDIO_GAP)
        req = {
            "assetType": "Audio",
            "displayName": f"ChronoHeist {key}",
            "description": f"Chrono Heist Tycoon SFX: {key}",
            "creationContext": {"creator": creator},
        }
        ext = os.path.splitext(path)[1].lower()
        body, ct = multipart([("request", json.dumps(req))],
                             [("fileContent", os.path.basename(path), SFX_MIME[ext], data)])
        c, t, d = http("POST", f"{API}/assets/v1/assets", body, ct, retries=2)
        if c != 200 or not d:
            err(f"sfx:upload:{key}", c, t)
            low = t.lower()
            if "moderated" in low:
                quota_hit = "аккаунт под модерацией (User is moderated) — остальные загрузки отложены"
            elif "quota" in low or ("limit" in low and "audio" in low):
                quota_hit = "квота аудио исчерпана"
            continue
        op_id = d.get("operationId") or (d.get("path") or "").split("/")[-1]
        st = {"sha256": sha, "operationId": op_id}
        state["sfx"][key] = st
        if d.get("done") and d.get("response"):
            resp, e = d["response"], None
        else:
            resp, e = poll_operation(op_id)
        if resp and resp.get("assetId"):
            st["assetId"] = int(resp["assetId"])
            st["moderation"] = (resp.get("moderationResult") or {}).get("moderationState")
            log(f"  {key}: загружен {st['assetId']} (moderation={st['moderation']})")
        elif e == "pending":
            log(f"  {key}: операция {op_id} ещё идёт — заберём при следующем запуске")
        else:
            err(f"sfx:operation:{key}", "-", e)
            st.pop("operationId", None)
        save_state(state)


def main():
    if not KEY:
        log("::error::Нет секрета ROBLOX_API_KEY")
        return 1
    state = load_state()
    products_ran = False
    server_size = None
    fatal = None
    try:
        creator = get_creator(state)
        sync_catalog(state, "products")
        products_ran = True
        save_state(state)
        sync_catalog(state, "passes")
        save_state(state)
        server_size = set_server_size(state)
        save_state(state)
        upload_sfx(state, creator)
    except SystemExit as e:
        fatal = str(e)
        log("::error::" + fatal)
    finally:
        save_state(state)
        result = {
            "sfx": {k: v.get("assetId", 0) for k, v in sorted(state["sfx"].items())},
            "passes": state["passes"],
            "products": state["products"],
            "serverSize": server_size,
            "errors": ERRORS,
        }
        log("=====ASSETS-JSON-BEGIN=====")
        log(json.dumps(result, ensure_ascii=False, indent=2))
        log("=====ASSETS-JSON-END=====")
    return 0 if products_ran else 1


if __name__ == "__main__":
    sys.exit(main())
