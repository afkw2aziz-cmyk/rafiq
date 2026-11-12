# PixelCompanion 🤖

A LOOI-inspired **AI desktop companion for Android** — a friendly procedural robot face that talks, answers questions, watches your stocks, and keeps you informed. Phone-only: no robot hardware required.

> **Clean-room build.** Inspired by LOOI's concept, but all code and art are original. No assets or code copied from LOOI.

![Flutter](https://img.shields.io/badge/Flutter-3-blue) ![Platform](https://img.shields.io/badge/Android-API%2026%2B-green) ![Version](https://img.shields.io/badge/version-1.4.0-cyan)

## ✨ Features

| | |
|---|---|
| 🗣️ **Conversational AI** | Chat with a real LLM (Google Gemini, optional key) — or a zero-dependency local fallback that always works offline |
| 🎭 **Living face** | 8 emotional states + 7 idle micro-moods (glances, blinks, yawns, sighs) — all procedural, ~0 KB |
| 🧠 **Smart intent routing** | "how much is tesla worth right now?" → stock skill. Gemini understands natural phrasing, with regex fallback when there's no key |
| 📰 **Hourly digest** | Al Jazeera headline + AI news + GitHub security advisories + top US stock movers, summarized in Arabic |
| 📈 **US stocks** | Live prices & movers from Yahoo Finance (no key required) |
| ☀️ **Weather** | Open-Meteo, current + forecast (no key) |
| 🔔 **Notifications insight** | Opt-in, privacy-first: reads app label + title only, in-memory, never body text |
| 📅 **Calendar & reminders** | On-device, with natural-language time parsing |
| 🌐 **Arabic-first** | Fully RTL, spoken replies via TTS |

## 🔐 Privacy

- **Opt-in by design**: the notification skill is **off by default**.
- Gemini key is stored **encrypted** (Android Keystore via `flutter_secure_storage`).
- Only your chat sentence + skill names are sent to the model — never notification bodies, calendar, or settings.
- Everything else (weather, stocks, calendar, reminders) works **without any key** and without third-party accounts.

## 🚀 Getting started

```bash
flutter pub get
flutter run          # needs a device/emulator
```

### Optional: enable Gemini chat

1. Get a free key from [Google AI Studio](https://aistudio.google.com/apikey).
2. Open the app → **Settings** → **Gemini API key** → paste → **Save** → **Test**.
3. Toggle **"فهم الطلبات بالذكاء الاصطناعي"** (Smart intent routing) for natural phrasing.

Without a key the app still works: local fallback answers time/date/jokes, and all data skills work.

## 🧪 Testing

```bash
flutter test
```

29 tests: face rendering & idle moods, stock parsing, digest routing, intent-router parsing (fences/prose/malformed JSON), skills.

## 📁 Structure

```
lib/
  core/        settings, state, theme
  services/    LLM router, intent router, digest sources, weather, stocks,
               notifications, calendar, TTS/STT, background scheduler
  skills/      chat, weather, stock, news, digest, reminders, calendar,
               notifications insight, system
  ui/          home (face + shortcuts), chat, skills, settings
docs/
  decisions.md, architecture.md, session-state.md
```

## 📄 License

All rights reserved. Personal use only — original code and art by the author.

---

*Built with Flutter. Companion name and personality are fully configurable in Settings.*
