# GlowAi Mobile (Flutter)

## Требования
1. Установить [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) и добавить в PATH.
2. `flutter doctor` без критических ошибок.
3. Backend на `localhost:8000` (`docker compose up --build` из корня).

## Запуск

```bash
cd c:\Glow_Ai\mobile
flutter pub get
flutter run
```

API URL по умолчанию для Android-эмулятора: `http://10.0.2.2:8000`  
Переопределение:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

Платформенные папки `android/` / `ios/` взяты из `app_dart/match_bloom` и переименованы под GlowAi.
