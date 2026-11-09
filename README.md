# Тестовое обби для Roblox

Игра собирается из кода без Roblox Studio: GitHub Actions собирает файл места через [Rojo](https://rojo.space) и публикует его через Roblox Open Cloud.

## Что внутри

- `src/server/Obby.server.luau` — строит трассу из 12 этапов (прыжки, балки над лавой, исчезающие платформы, вращающиеся балки), чекпоинты, финиш.
- `src/client/Hud.client.luau` — плашка «Этап N / 12» и окно победы с кнопкой «Пройти заново».
- `.github/workflows/deploy.yml` — сборка и публикация при каждом пуше в `main`.

## Настройка (один раз)

1. ID игры уже прописаны в `.github/workflows/deploy.yml` (Universe ID 1195242587, Place ID 3327609598).
2. Создать API-ключ: Creator Hub → Open Cloud → API Keys → Create API Key. Добавить доступ **universe-places** (Place Publishing) для этой игры, операция **Write**. В IP-адресах указать `0.0.0.0/0`.
3. В репозитории: Settings → Secrets and variables → Actions → New repository secret. Добавить секрет `ROBLOX_API_KEY`.
4. Actions → «Сборка и публикация» → Run workflow.

Публикация полностью заменяет содержимое места.
