# Decisions

Defaults chosen where the brief left room; every deviation is recorded here.

| # | Decision | Rationale | Alternative rejected |
|---|---|---|---|
| 1 | Procedural Flutter face (`CustomPainter` + `AnimationController`) | No designer/`.riv` file available; keeps art 100% original and the APK small | Rive (needs authored `.riv`), Lottie (needs after-effects assets) |
| 2 | Device calendar via a small Kotlin `MethodChannel` over `CalendarContract` | No Google Cloud project, OAuth consent, or SHA-1 fingerprint needed; works offline; writes directly to the user's calendar | `googleapis` OAuth (blocked on credentials), third-party `device_calendar` plugin (extra build risk on API 37) |
| 3 | Settings in `SharedPreferences`, history in Hive | Settings must be readable from the WorkManager isolate without Flutter bindings | Hive for everything (isolate init fragility) |
| 4 | No Drift/SQL | One relational need (reminders) is covered by system notifications + Hive list; avoids codegen | Drift + build_runner |
| 5 | WorkManager instead of an always-on foreground service | Android 13+ mic FGS is user-visible, battery-heavy, and blocked from starting at boot; WorkManager survives reboot and respects Doze | `flutter_background_service` with mic type |
| 6 | Push-to-talk by default, optional hands-free | "Hey Pixel" hotword in background is unreliable on Android 13+ without a licensed wake-word engine | Always-listening VAD (drains battery, Play policy issues) |
| 7 | News via Hacker News Algolia + Google News RSS (no key), NewsAPI optional | Works out of the box | NewsAPI-only (requires key, rate-limited) |
| 8 | Stocks via Yahoo Finance chart endpoint (free, no key) | Stooq's `q/l/` endpoint started returning an error page to this device, breaking all quotes; Yahoo's `/v8/finance/chart` works without a key and returns price, previous close, and currency in one call | Stooq CSV (broken), Alpha Vantage (key + rate limits) |
| 8b | Stock skill resolves a ticker from the question (symbol, Arabic company name, or Yahoo search) | The original skill only summarised the saved watchlist, so "what is the price of TSLA?" was impossible; now a specific ticker is answered directly | Watchlist-only (no ad-hoc queries) |
| 9 | Weather via Open-Meteo + geocoding, city from settings | No key, no location permission needed | `geolocator` (permission + plugin) |
| 10 | Gemini default, local rule engine fallback | App stays useful with no key; provider is swappable | Hard dependency on one vendor |
| 11 | Bilingual UI (Arabic/English) with RTL | Owner language is Arabic; TTS/STT locales switch with UI | English-only |
| 12 | `compileSdk 36`, `targetSdk 36`, `minSdk 26` | Stable toolchain support; API 37 is too new for plugin ecosystem | `targetSdk 37` |
| 13 | Local model support is "adapter only", not bundled | Measured ceiling on this Pixel 6 is ~1.7B (4B is OOM-killed); shipping llama.cpp would balloon the APK | Bundled Gemma/Qwen |
| 14 | Notification listening is opt-in and off by default | Reading all notifications is a privacy hazard; the skill only exposes summaries the user requests | Auto-read aloud |
| 15 | Idle face uses a timed mood state machine, not authored animation clips | No designer/PAG pipeline; 8 procedural moods (glance L/R, double-blink, yawn, smile, sigh, eye-orbit) match LOOI's *felt* liveliness at ~0 asset cost | PAG/Rive packs (843 MB, needs authoring) |
| 16 | Notification insight captures **app label + title only**, in-memory, capped 50, drained on read | Smallest possible read to answer "what did I miss?" without storing notification bodies or writing to disk | Full notification body capture, persisted |
| 17 | Notification access is a separate Android permission granted via system Settings, not a runtime request | Android requires the user to toggle Notification Access in Settings; the skill detects it and points there instead of failing silently | `NotificationListenerService` without the grant (impossible) |
