# GlowAi MVP

Рабочий B2C MVP: план ухода за кожей в путешествии с учётом климата, симптомов и (опционально) селфи.

## За 1 команду

```powershell
cd c:\Glow_Ai
.\scripts\start-mvp.ps1
```

Откройте UI: **http://localhost:8000/app/**  
Swagger: **http://localhost:8000/docs**

## Что умеет MVP

1. Страна → поиск любого города (Open-Meteo Geocoding + popular)
2. Даты поездки / режим SOS
3. Тип кожи + симптомы (чипы)
4. Селфи (опционально) **только с согласием** — фото не сохраняется на сервере
5. Климат home→destination (Open-Meteo); UI передаёт lat/lon
6. Прогноз кожи, why, travel-kit, бейдж движка (нейросеть / правила)
7. **Аккаунт** (email/password + JWT): сохранение проверок в профиль
8. **Чат follow-up** по конкретной проверке (LLM + дисклеймер)
9. Климат по датам поездки (прогноз / сезонный архив) + окно follow-up с email-воркером
10. Локальный кэш последнего результата (offline) + дисклеймер «не медуслуга»

## Аккаунт / профиль / чат

```env
DATABASE_URL=sqlite:////data/glowai.db
JWT_SECRET=dev-change-me-glowai-jwt
JWT_EXPIRE_HOURS=336
CHAT_MAX_MESSAGES_PER_DAY=40

# SMTP optional — без него в APP_ENV=dev API отдаёт dev_verify_code
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASSWORD=
SMTP_FROM=
```

API:
- `POST /api/v1/auth/register` (`accept_terms`) | `verify-email` | `login`
- `POST /api/v1/auth/forgot-password` | `reset-password`
- `GET|DELETE /api/v1/auth/me`
- `POST|GET /api/v1/checks` (`parent_check_id`, `remind_in_hours`) · `GET /due`
- `GET|POST /api/v1/checks/{id}/messages`

Smoke:

```powershell
.\scripts\smoke-mvp.ps1
.\scripts\smoke-auth.ps1
```

Гостевой analyze без аккаунта работает; сохранение и чат — после входа (вкладка **Профиль**).
Юр.тексты runtime: `/legal/terms`, `/legal/privacy` (файлы в `backend/legal/`).

В `APP_ENV=prod` старт падает без сильного `JWT_SECRET`, SMTP и явных `CORS_ORIGINS`.

## Деплой на Amvera (web)

```powershell
.\scripts\prepare-amvera.ps1
# SMTP + CORS + JWT → переменные в панели Amvera → push
```

Файлы: `Dockerfile`, `amvera.yaml`. Секреты только локально / в панели Amvera (не в git).

## Нейросеть

```env
LLM_PROVIDER=openai_compatible
LLM_API_KEY=...
LLM_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/
LLM_MODEL=gemini-3-flash-preview
LLM_ALLOW_RULE_BASED_FALLBACK=true
```

`GET /api` → `llm_configured: true`.

## Пилот: ПДн / селфи / удаление

Фото не пишется в БД; условия пилота — `backend/legal/`. Удаление аккаунта — в профиле или `DELETE /api/v1/auth/me`.

## Раздельный запуск

```powershell
docker compose up -d --build
.\scripts\build-web.ps1
docker compose restart backend

cd backend
pip install -r requirements.txt
pytest -q

cd ..\mobile
flutter pub get
flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Структура

```
backend/     FastAPI + SQLite volume + web UI + legal/
mobile/      Flutter (Сегодня / Поездка / Профиль)
scripts/     start-mvp / build-web / prepare-amvera / smoke-*
Dockerfile   образ для Amvera (корень репо)
```

