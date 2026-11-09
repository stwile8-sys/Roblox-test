# Chrono Heist Tycoon — прогресс сборки

ТЗ v2.0 (все ответы заказчика учтены) — см. историю чата; договор модулей — docs/ARCH.md.
Работаем в ветке `dev`. Плейс закрыт (Private). Релиз = слияние в `main`.

## Готово
- Каркас: default.project.json (портрет, ночное освещение), docs/ARCH.md
- shared: Config/Palette, Config/Game (весь баланс), Config/Assets (ID, заполняет пайплайн), Net, Lang/L
- server/Data/Profiles: сохранения User_<id>, блокировка сессии, MemoryStore-сессии, офлайн-кража (атомарно), журнал краж
- server/Game: Ctx (контекст, состояние, тосты), Bases (владение, стены, щит, якоря, маяк), Economy (доход, конвейер,
  апгрейды, стройка, энергия), Raid (скан, вторжение, взлом, кража, перенос, дубинка, ловушки, замок, месть),
  Progress (ребёрс, квесты, серия, достижения, титан, пропуск, VIP)

## Агенты (могли не закончить — проверить файлы)
- Существа: src/shared/Art/Defs.luau, src/shared/Art/Build.luau, src/client/Art/Animate.luau
- Мир: src/server/World/Island.luau, src/server/World/BaseBuilder.luau, src/client/WorldFx.luau
- Звуки/товары: ветка `assets` (tools/sfx, tools/assets/pipeline.py, .github/workflows/assets.yml) → ID в Config/Assets.luau

## Осталось
1. server/Game/Shop.luau — геймпассы (VIP, AutoCollect, ScannerPlus, SecondFloor), ProcessReceipt с идемпотентностью
   (receipts в профиле, saveNow до PurchaseGranted), скины за осколки, тестовые покупки владельца без Robux.
2. server/Game/Social.luau — кланы (DataStore, фильтр имени, TextChannel, +30%/+20%, ≤3 на базе), трейд (2 подтверждения,
   атомарный обмен), лидерборды (OrderedDataStore: Titan_S<сезон>, Collection, Clans) + стена в хабе.
3. server/Game/Seasons.luau — тема по времени, Island.setSeason, клетка и сезонный артефакт на алтаре (s1..s6), порталы.
4. server/Game/Anticheat.luau — скорость/телепорт/спам/роботичность → suspicion, тихий бан 24ч (S.shadow), BanAsync.
5. server/Game/Bots.luau — NPC (CreateHumanoidModelFromDescription): вор-рейдер, база-бот с охранником, бот трейда
   (только при Config.Game.TEST_TOOLS и только у владельца плейса); вор из обучения.
6. server/Game/Tutorial.luau — FTUE 90 сек: бесплатная «Капля Времени», NPC-вор крадёт, погоня к логову (makeDen),
   забрать артефакт лучше, затем NPC-рейдер → кнопка «Замок».
7. server/Game/OfflineBases.luau — заполнение пустых участков базами офлайн-игроков (Profiles.recentPlayers, isOnline, peek),
   проверка раз в 60 сек, снятие базы при входе владельца.
8. server/Game/Analytics.luau — AnalyticsService (ftue_first_steal, raid_*, offline_collect, purchase_*, rebirth_completed).
9. server/Main.server.luau — запуск Island/Bases/систем, вход/выход, офлайн-доход + «Вас обокрали», views состояния,
   диспетчер Act/Do, автосейв, BindToClose, Bases.onOwnerLeaving при выходе.
10. Клиент: Main.client, UI/Kit (взять из старого git show origin/main:src/client/UI/Kit.luau), HUD по ТЗ 6.2,
    экраны (Сканер, Рейд, Магазин 5 вкладок, Коллекция, Лидерборды, Квесты+серия, Трейд, Кланы, Верстак, Пьедестал,
    Ребёрс), попапы 6.4, позы персонажа кодом (Motor6D.Transform по атрибуту Pose), VFX/звук по Fx, музыка по зонам,
    хоткеи E/F/Q, дверь-ворота своей базы (CanCollide локально), подсказки ProximityPrompt (steal/manage/buy) по ролям.
11. Lang/Strings.luau — ru + en (+ остальные языки агентом-переводчиком).
12. .github/workflows/deploy.yml — публиковать и из `dev`. Сборка rojo + luau-lsp локально (/home/claude/tools), пуш, проверить деплой.
