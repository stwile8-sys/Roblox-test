# План по 3D-моделям (ветка `models`)

Рабочий список: что уже сделано и загружено, что осталось. ID и размеры — в `docs/MODELS.md`.
Правила для всех: гладкий милый лоу-поли, тёмный контур #2A2140, опора — низ по центру, перед на −Z,
без символов, похожих на руны, и без парных молний.

## Сделано и загружено (63 модели, все прошли модерацию)

**Первая очередь (33)**
- [x] Пьедесталы: `pedestal`, `pedestalRich`, `decoyPedestal`
- [x] Острова: `islandBig` (~180), `islandMid` (~95)
- [x] Стены: `wall1`…`wall5`; ворота: `gate1`…`gate5`
- [x] Мост: `bridge`
- [x] Кристаллы: `crystalHub`, `crystalA`, `crystalB`, `crystalC`
- [x] Декор: `tree`, `bush`, `lantern`, `crate`, `rock`, `mushroom`
- [x] `conveyor` (прямая секция — устарела, конвейер теперь кольцевой), `portal` (арка)
- [x] `bench` (верстак), `beacon` (переделан: столб ~26)
- [x] Ловушки: `mine`, `slowField` (переделан: купол), `blackHole`

**Вторая очередь (30)**
- [x] Хаб: `chest` + `chestLid` (крышка отдельно), `chestPedestal`, `beltArc` (1/44 кольца),
      `portalStart`, `portalEnd`, `skinPodium`, `leaderboard`, `rebirthAltar`, `statuePedestal`, `seasonPortal`
- [x] Базы: `lockButton` (первая версия), `collectPad`, `floor2`, `stairs`
- [x] Сезонный остров: `titanAltar`, `cage` (прутья `Bar1`…`Bar8`)
- [x] Декор сезонов: `s1Pumpkin`, `s1Torch`, `s2Tree`, `s2Snowman`, `s3Palm`, `s3Shells`,
      `s4Sakura`, `s4Flowers`, `s5Planet`, `s5Meteor`, `s6Coral`, `s6Bubbles`
- [x] Предмет: `club`

## Осталось

**Шаг 1 — две модели по последней просьбе**
- [x] `collectPlate` — плита сбора 10×10, высота ~0.6: золотая, толстая рамка, в центре большая монета
      (круг с ободком), по углам маленькие монетки; свет — узлы `Glow_FFE066`. (`collectPad` остаётся как старый вариант.)
- [x] `lockButton` — переделать: тумба ~9, высота ~2.5, кнопка отдельным узлом `Button` (перекрашивается),
      рисунок на кнопке. (Сообщение оборвалось на слове «рисуно…» — делаю простой рельефный замочек.)

**Шаг 2 — существа (по желанию, последняя очередь)**
- [ ] 40 существ из `Art/Defs.luau`: 10 common, 10 rare, 8 epic, 6 legendary, 6 chrono
- [ ] 6 сезонных Титанов `s1`…`s6`
- Узлы по ролям из `Art/Build.luau` (Body, Head, Eye, Limb, Ring, Shard, Glow_…), чтобы клиент мог анимировать.

**После каждого шага:** пуш в `models` → workflow загружает → проверить отчёт `tools/models/report.md`.
