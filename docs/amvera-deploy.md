# Деплой GlowAi на Amvera (web)

Один контейнер: FastAPI + Flutter UI на `https://<проект>.amvera.ru/app/`.

## Что уже лежит в репозитории

| Файл | Назначение |
|------|------------|
| `Dockerfile` | Образ для Amvera (контекст = корень репо) |
| `amvera.yaml` | Порт `8000`, том `/data` |
| `.env.amvera.example` | Шаблон переменных (можно в git) |
| `.env.amvera` | Локальный заполненный шаблон (не в git) |
| `backend/web/` | Собранный UI (должен быть в образе) |

Локальный `docker compose` по-прежнему использует `backend/Dockerfile` — не путать.

## Перед пушем (на вашем ПК)

1. Собрать web **без** localhost API URL (same-origin):

```powershell
cd c:\Glow_Ai
.\scripts\prepare-amvera.ps1
```

Или вручную:

```powershell
cd c:\Glow_Ai\mobile
$env:Path = "C:\flutter\flutter\bin;" + $env:Path
flutter build web --release --base-href /app/ --no-tree-shake-icons --no-wasm-dry-run
Copy-Item -Recurse -Force .\build\web\* ..\backend\web\
```

2. Проверить, что есть шрифты иконок:

```powershell
Test-Path c:\Glow_Ai\backend\web\assets\FontManifest.json
Test-Path c:\Glow_Ai\backend\web\assets\fonts\MaterialIcons-Regular.otf
```

Оба должны быть `True`.

## Создание приложения в Amvera

1. [amvera.ru](https://amvera.ru) → новое приложение → окружение **Docker**.
2. Подключить Git (push в remote Amvera) **или** загрузить архив/файлы проекта.
3. В корне проекта должны уехать как минимум:
   - `Dockerfile`, `amvera.yaml`
   - `backend/app/`, `backend/web/`, `backend/legal/`, `backend/requirements.txt`
4. `docker-compose.yml` Amvera **игнорирует** — это нормально.

## Переменные окружения

Amvera: раздел **Переменные** / **Секреты** → добавить по одной **или** перенести из `.env.amvera`.

Минимум для старта без падения prod-gate:

```
APP_ENV=prod
JWT_SECRET=<из .env.amvera, уже сгенерирован>
CORS_ORIGINS=https://<ваш-проект>.amvera.ru
DATABASE_URL=sqlite:////data/glowai.db
SMTP_HOST=...
SMTP_PORT=587
SMTP_USER=...
SMTP_PASSWORD=...
SMTP_FROM=GlowAi <ваш@email>
SMTP_USE_TLS=true
REQUIRE_SMTP_IN_PROD=true
```

Порядок:

1. Первый деплой с временным `CORS_ORIGINS=https://example.com` **не пройдёт**, если SMTP пустой — сначала заполните SMTP.
2. Либо временно (только для отладки, не для пилота): `REQUIRE_SMTP_IN_PROD=false` — тогда письма verify не уйдут, коды в JSON в prod не отдаются.
3. После появления URL Amvera выставьте точный `CORS_ORIGINS` и **перезапустите** контейнеры.

Секреты (`JWT_SECRET`, `SMTP_PASSWORD`, `LLM_API_KEY`) лучше помечать как **Секрет**.

## После деплоя — проверка

```
https://<проект>.amvera.ru/healthz   → {"status":"ok",...}
https://<проект>.amvera.ru/api       → web_ready: true
https://<проект>.amvera.ru/app/      → UI
https://<проект>.amvera.ru/docs      → Swagger
https://<проект>.amvera.ru/legal/terms
```

Жёсткое обновление UI: Ctrl+F5.

## Типичные ошибки

| Симптом | Причина |
|---------|---------|
| Контейнер Exit 2, «PROD GATE» | Слабый JWT / нет SMTP / CORS=`*` |
| Белый экран | Старый `backend/web` без `--base-href /app/` или без шрифтов |
| Иконки-квадратики | Нет `assets/fonts/MaterialIcons-Regular.otf` в образе |
| API на 127.0.0.1 | Web собрали с `--dart-define=API_BASE_URL=http://127.0.0.1:8000` — пересоберите без define |
| Потерялись пользователи | Нет тома `/data` или сменили persistenceMount |

## Обновление версии

1. `.\scripts\prepare-amvera.ps1`
2. Commit + push в Amvera (или повторная загрузка файлов)
3. Дождаться сборки, проверить `/healthz` и `/app/`

## Не входит в этот пилот

Отдельный фронт-хостинг, Postgres, мобильные сторы, push-уведомления.
