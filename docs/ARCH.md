# Chrono Heist Tycoon — архитектура и договор между модулями

Игра собирается Rojo из `src/` без Roblox Studio. Публикация: GitHub Actions (`deploy.yml`) при пуше в `dev` и `main`.
Все модули — Luau, `--!strict` где разумно, код проверяется `luau-lsp analyze` (см. `.github/workflows/check.yml`).
Комментарии в коде — по-русски. Никаких ассетов из Studio: всё строится из Part/WedgePart/CornerWedgePart/
CylinderPart (Part.Shape = Cylinder/Ball)/MeshPart НЕЛЬЗЯ (нет мешей). Свет — PointLight/SurfaceLight, эффекты — ParticleEmitter/Beam/Trail
с текстурами по умолчанию (Texture = "" или встроенные `rbxasset://textures/particles/sparkles_main.dds`).

## Раскладка Rojo

| Папка | Куда попадает |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |

## Палитра (HEX из ТЗ) — `Shared.Config.Palette`

```
warm:  orange #FFB347, gold #FFE066, wood #8B5A2B, stone #C2A878
cold:  chrono #00E5FF, thief #7B2FF7, alarm #FF2E63, steel #2C3E50
misc:  night #1A1A2E, white #FFFFFF, success #39FF14
```

## Мир (координаты в стадах, ось Y вверх)

- Хаб (лобби) — диск радиусом 70, верх на y = 0, центр (0,0,0).
- 8 баз. База `i` (1..8): угол `a = (i-1) * 45°`, центр `P = (sin a * 230, 0, cos a * 230)`.
  `CFrame` базы = `CFrame.lookAt(P, Vector3.new(0, 0, 0))` — локальная **−Z смотрит на хаб** (там ворота).
- Пол базы 120×120 (локально X, Z ∈ [−60, 60]), верх пола на локальном y = 0.
- Мосты: от края хаба до передней кромки каждой базы (вдоль направления на базу), ширина 14.
  Боковые мосты между соседними базами (кольцо).
- Сезонный остров висит над хабом: центр (0, 90, 0), диск радиусом 45. Попасть — портал на хабе
  (часть `workspace.Map.Hub.SeasonPortal`), обратно — портал на острове (`workspace.Map.Season.ReturnPortal`).
  Порталы обрабатывает сервер (телепорт по касанию).
- Ниже y = −60 — пустота; упавший игрок возрождается на своей базе.

## Локальная раскладка базы (агент «мир» строит, сервер использует по именам)

```
workspace.Bases.Base<i>        Model, атрибут Index = i, PrimaryPart = Floor
  Floor                        Part 120×4×120, верх на y=0
  Spawn                        SpawnLocation у ворот внутри, локально (0, 0.5, -42), Neutral=false, Enabled=true
  Walls/                       Folder, 12 сегментов (Part'ы), имена F1 F2 F3 (перед, F2 — ворота), R1 R2 R3 (право, +X),
                               B1 B2 B3 (зад, +Z), L1 L2 L3 (лево, −X). Высота 14, толщина 2, по периметру на |x| или |z| = 58.
                               У F2 атрибут Gate = true. Визуал уровня — дочерние детали сегмента (декор), сам сегмент —
                               коллизия. Сломанный сегмент сервер делает Transparency=1, CanCollide=false (+ декор прячет).
  Pedestals/                   Folder, P1..P10 (первый этаж), P11..P20 (второй этаж, только если куплен).
                               Каждый — Model с частью `Top` (верх пьедестала), над ней сервер ставит артефакт.
                               P1..P5 в ряд на z=+25, x = -36,-18,0,18,36; P6..P10 на z=+42 с теми же x.
  Belt                         Part — лента конвейера вдоль X: от x=-46 до x=+46, z = +5, верх на y = 1.2, ширина 6.
                               Дочерние Part'ы `Start` (x=-46) и `End` (x=+46) — невидимые маркеры над лентой.
  Collect                      Part 10×0.4×10 — плита сбора дохода, локально (0, 0.2, -22), с подсветкой.
  Bench                        Model «стол апгрейдов» (верстак), локально (-38, 0, -26), часть `Prompt` для ProximityPrompt.
  Traps/                       Folder, T1..T8 — плоские Part 6×0.3×6 (слоты): (-25,-48) (25,-48) (-50,-20) (50,-20)
                               (-50,20) (50,20) (-25,50) (25,50) по (x, z).
  Beacon                       Model маяк в углу (52, 0, -52): часть `Light` (неоновый столб), BillboardGui `Tag`
                               с TextLabel `Name` и `Level`. Цвет света задаёт сервер.
  Floor2/                      Folder, второй этаж (строится функцией setSecondFloor): платформа y=22 над задней половиной
                               (z от 8 до 58), лестница вдоль правой стены, свой конвейер `Belt2` (с `Start`/`End`)
                               на z=+14, пьедесталы P11..P20 (ряды z=+30 и z=+46).
  Decor/                       тёплые фонари, растения, «золотые частицы» дохода над конвейером.
```

Зона базы (для логики): точка внутри базы, если в локальных координатах |x| < 58, |z| < 58, −5 < y < 45.

## Артефакты на сцене

Сервер создаёт только **невидимые якоря** (`workspace.Arts`, Part, Anchored, CanCollide=false, Transparency=1,
тег CollectionService `Art`), клиент сам строит и анимирует существо поверх якоря.
Атрибуты якоря: `Id` (string, id из `Shared.Art.Defs`), `Lvl` (number), `Kind` ("pedestal" | "belt" | "carry" | "season" | "den" | "decoy"),
`Owner` (userId), `Base` (индекс базы), `Slot` (номер пьедестала), `Price` (для belt), `Anim` (string-событие:
"collect" | "stolen" | "return" | "rebirth", с атрибутом `AnimT` = os.clock сервера при смене — клиент проигрывает
одноразовую анимацию, когда `AnimT` меняется). Размер якоря = размер существа (по редкости).

## Существа — `Shared.Art.Defs`, `Shared.Art.Build`, клиент `Client.Art.Animate`

- `Defs.LIST` — массив определений, `Defs.BY_ID[id]`. Поля: `id`, `name = {ru=, en=}`, `rarity`
  ("common" | "rare" | "epic" | "legendary" | "chrono"), `income` (Cash/сек на 1 уровне), `color` (Color3), `glow` (Color3),
  `shape` (строка-рецепт для Build), `emotion` ("smile" | "surprise" | "angry" | "sleepy" | "sly"), `perk` (только chrono).
- Состав: 10 common, 10 rare, 8 epic, 6 legendary, 6 chrono = 40. Плюс 6 сезонных (`s1`..`s6`) — скин легендарного
  «Титан Вечности» (`l_titan`) в теме сезона, редкость legendary, income 150.
- `Defs.RARITY[r] = {index=1..5, size=1|2|3|5|4, weight=60|25|10|4|1, color=Color3, name={ru,en}}`.
- Перки chrono: `silent` (тихий взлом), `step` (иммунитет к замедлению), `steel` (стены +20% HP),
  `double` (20% шанс не потерять добычу при провале), `echo` (+15% дохода), `shield` (+10 сек замка).
- `Build.model(id: string, scale: number?): Model` — модель из деталей, `PrimaryPart` = центр, все детали Anchored,
  CanCollide=false, CastShadow=false, Massless. Детали с ролями помечены атрибутом `Role` ("body", "head", "eye",
  "lid", "ring", "shard", "glow", "limb") для анимаций. Габарит ≈ `RARITY.size` при scale=1.
- `Animate` (клиент) рендерит существо на каждом якоре с тегом `Art` в радиусе 220 стад от камеры, анимирует
  кодом (покачивание, моргание, поворот головы к игроку, пульсация, вращение колец, глитч у chrono), реагирует на
  `Anim`/`AnimT`. Анимация плавная (CFrame по времени, синусы/твины), бюджет: одна функция на RenderStepped
  обходит все видимые существа, без созданий/удалений инстансов в кадре.

## Сеть — `Shared.Net`

`Remotes` в ReplicatedStorage: `Act` (RemoteFunction — действие с ответом), `Do` (RemoteEvent — частые действия: удар, взлом),
`State` (сервер → клиент: частичный снимок состояния), `Notify` (тост: ключ перевода + аргументы + вид),
`Popup` (большие окна), `Fx` (эффекты/звуки всем: тип, позиция, данные), `Board` (лидерборды), `Trade` (окно обмена).

## Звуки и товары — `Shared.Config.Assets`

```lua
return {
  sfx = { coin=…, hack=…, wallBreak=…, steal=…, caught=…, escape=…, upgrade=…, rebirth=…, trap=…, alarm=…, buy=…,
          click=…, pop=…, whoosh=…, voiceCommon=…, voiceRare=…, voiceEpic=…, voiceLegendary=…, voiceChrono=… },
  music = { lobby=1843529601, base=117013055420452, raid=9045389581, season=131361167613190 },
  passes = { VIP=…, AutoCollect=…, ScannerPlus=…, SecondFloor=… },
  products = { Starter=…, Titan=…, Shards100=…, Shards550=…, Shards1500=…, Energy5=…, BoostX2=…, SeasonPass=… },
}
```
ID — числа (asset id / gamepass id / product id). Пока ID нет — 0, код это переживает.
