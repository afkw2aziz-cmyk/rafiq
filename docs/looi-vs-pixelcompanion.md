# LOOI (actual) vs PixelCompanion (implemented) — REA Comparison

> Scope: compare the **actual characteristics of LOOI** against **what this repo actually
> implements**, using REA (`agent-reach`) for external corroboration and the local APK
> static inspection as ground truth. **The robot / hardware link is deliberately excluded**
> from this comparison — only the human-facing app behaviour is judged.
>
> Sources
> - Ground truth: `looi_backup/com.TangibleFuture.looiRobot_2.9.3/*.apk`, inspected with
>   `aapt2 dump permissions`, `unzip -l`, and asset inventory. See `docs/looi-spec.md`.
> - External (REA): `agent-reach get rss.feed` on Google News query
>   `"LOOI" robot desktop companion ChatGPT features`, corroborating press titles
>   (Hackster.io 2024-02-28, Geeky Gadgets 2024-03-22, The Tech Outlook 2024-03-30,
>   EFTM 2025-01-08, Android Headlines 2025-07-10, Gogi Tech 2025-09-22,
>   Cybernews 2025-12-30, techbuzzireland 2026-02-11).
> - Implementation: `pixel_companion/lib/**` (3,900 LOC, read directly).
>
> Honesty note: REA on this machine exposes only `rss.feed` and `youtube.info/transcript`
> channels. It has **no APK-inspection commands** (the `rea.inspect_apk` /
> `rea.android_resources_list` calls sketched in the brief do not exist in this build).
> APK facts therefore come from direct static inspection of the local APK, and REA is used
> for the external-press cross-check only. Web search was unavailable during this analysis.

---

## 1. Method

| Step | Tool | What it produced |
|---|---|---|
| 1. Real LOOI facts | `aapt2 dump permissions`, `unzip -l`, `strings` on the 2.9.3 APKs | Verified permission list, asset inventory (InspireFace, ML Kit face mesh, silero VAD, 627 `.pag` files) |
| 2. External cross-check | REA `rss.feed` (Google News) | 8+ independent press pieces confirming the product's public traits |
| 3. Implemented facts | direct read of `lib/**` | Face states, skill list, services, settings model |

The goal is a **capability-by-capability table**, each row grounded in an observable
on either side — not a marketing claim.

---

## 2. Verified LOOI characteristics (app-level, no robot)

| # | Characteristic | Evidence |
|---|---|---|
| L1 | Native Kotlin + Jetpack Compose app | DEX/class names, no Flutter/RN runtime |
| L2 | On-device face detection/recognition | `assets/inspireface/*` (~17 MB payload) |
| L3 | Face-mesh / object detection | `assets/mlkit_facemesh/*`, `mlkit_odt_localizer` |
| L4 | Always-on voice activity detection | `assets/silero_vad.onnx` (1.8 MB) |
| L5 | Large vector animation system for the face | 627 `*.pag` files (libpag), 843 MB split payload |
| L6 | Reads phone notifications to react | `BIND_NOTIFICATION_LISTENER_SERVICE` |
| L7 | Calendar-aware reminders | `READ_CALENDAR` + `WRITE_CALENDAR` |
| L8 | Camera + mic capture | `CAMERA`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS` |
| L9 | Boot persistence | `RECEIVE_BOOT_COMPLETED` |
| L10 | Cloud-mediated chat (no key in APK) | server-side LLM backend; Internet + auth |
| L11 | China-centric social login/sharing | ShareSDK / Tencent / Weibo entries |
| L12 | Ad/attribution + location (neverForLocation flag) | `AD_ID`, `freemme.permission.msa`, `ACCESS_FINE_LOCATION` |

Public press (REA) consistently frames it as: "turns your old phone into a ChatGPT AI robot",
"human-like conversations", "desktop companion", "expressive face". Nothing in the press
contradicts the APK evidence.

---

## 3. Implemented PixelCompanion characteristics

| # | Characteristic | Evidence in repo |
|---|---|---|
| P1 | Flutter (Dart 3) app | `lib/main.dart`, `pubspec` |
| P2 | Procedural `CustomPainter` face, 8 states | `lib/core/state.dart` (`CompanionState`: idle, listening, thinking, speaking, happy, sad, surprised, sleeping) |
| P3 | 3 character variants + user-renameable + personality | `lib/core/settings.dart` (`variant`, `companionName='Pixel'`, `personality='cheerful'`) |
| P4 | Blink + breathing animation | `lib/ui/face.dart` (blink `Timer`, `breathing = 1 + sin(...)*0.012`) |
| P5 | Push-to-talk STT (no always-on VAD) | `lib/services/stt_service.dart` (`listenFor: 30s`) |
| P6 | TTS pipeline | `lib/services/tts_service.dart` |
| P7 | 7 skills, toggleable | `lib/skills/registry.dart` → system, weather, reminder, calendar, chat, news, stock |
| P8 | Calendar via system CalendarContract (no OAuth) | `lib/services/calendar_service.dart` (Kotlin bridge) |
| P9 | LLM provider abstraction + local rule fallback | `lib/services/llm.dart`, `docs/decisions.md` §10 |
| P10 | WorkManager morning brief + stock polling | `lib/services/background_worker.dart` |
| P11 | Bilingual AR/EN with RTL | `docs/decisions.md` §11 |
| P12 | Network egress log surfaced in Settings | `docs/architecture.md` (NetworkLog) |
| P13 | No notification listener, no camera | absent from `android/` manifest and `lib/` |

---

## 4. Side-by-side capability comparison

Legend: ✅ parity · 🟡 partial / different approach · ❌ missing on PixelCompanion side ·
➖ intentionally out of scope (robot / privacy)

| Capability | LOOI (actual) | PixelCompanion (this repo) | Verdict |
|---|---|---|---|
| Language / stack | Kotlin + Compose | Flutter + Dart | 🟡 different, both native-feel |
| Expressive animated face | 627 PAG vector animations, authored art | Procedural painter, 8 states, blink+breathe | 🟡 state coverage full; **richness lower** (no authored micro-animations like glance/yawn/smile) |
| Idle micro-animations | Dense (PAG timeline packs) | Only blink + breathing | ❌ needs work (spec asked 12+) |
| Character variants | Unknown from APK; likely fixed art | 3 rendered variants (palette+shape), user-rename, personality presets | ✅ parity or better on configurability |
| Always-on VAD / wake gate | ✅ silero VAD on-device | ❌ push-to-talk only (documented trade-off) | 🟡 deliberate: battery + Play policy |
| Speech-to-text | ✅ | ✅ on-device `speech_to_text` | ✅ parity |
| Text-to-speech | ✅ | ✅ `flutter_tts` | ✅ parity |
| Interruptible speech | ✅ implied by VAD gate | 🟡 TTS stop supported, but no auto duck on user speech | 🟡 |
| Camera / face recognition | ✅ InspireFace + ML Kit mesh | ❌ none | ✅ **better privacy** (not a loss for phone-companion goal) |
| Notification reactions | ✅ notification listener | ❌ none | ❌ missing vs a KEEP item in spec |
| Calendar reminders | ✅ read/write | ✅ read/write via CalendarContract | ✅ parity (no OAuth = simpler setup) |
| Cloud LLM chat | ✅ server-mediated, no key in APK | ✅ Gemini + swappable providers + local fallback | ✅ parity (arguably more transparent: user-supplied key) |
| Proactive briefs / alerts | ✅ reminders + backend push | ✅ morning brief + stock thresholds (WorkManager) | ✅ parity |
| Boot persistence | ✅ RECEIVE_BOOT_COMPLETED | ✅ WorkManager survives reboot | ✅ parity |
| Drone/robot control | ✅ Bluetooth servo + firmware | ➖ excluded | ➖ by design |
| Social login / sharing | ✅ ShareSDK/Tencent/Weibo | ❌ none | ✅ **better** (irrelevant, less tracking) |
| Ad ID / attribution SDKs | ✅ `AD_ID`, MSA | ❌ none | ✅ **better privacy** |
| Permission surface | 30 permissions incl. Bluetooth×5, camera, location, phone state | mic, notifications, calendar (calendar only if enabled) | ✅ **much smaller** |
| Privacy / data egress screen | not evidenced | ✅ NetworkLog view | ✅ **better** |
| Localization | zh/en (split_config.en) | ar/en + RTL | 🟡 parity, different languages |
| Offline usefulness | unclear (server-mediated) | local rule fallback + local skills | ✅ **better** off-device |
| APK size footprint | 843 MB animation pack + 17 MB face SDK | single small APK (procedural face) | ✅ **better** |

---

## 5. Where LOOI is genuinely ahead (and worth copying — as patterns, not assets)

1. **Richness of facial expression.** 627 authored PAG timeline clips vs our single painter.
   The gap is *authoring*, not architecture — our 8-state machine is the right backbone.
2. **Always-on interaction.** VAD lets LOOI feel ambient; we are tap-to-talk. This is the
   biggest felt difference in daily use.
3. **Notification awareness.** LOOI reacts to the phone's own events; we ignore them.
   (Our spec listed this as a KEEP; implementation dropped it — see §6.)

## 6. Where the spec and the implementation disagree (self-audit)

Checked the brief's acceptance criteria against the code:

| Brief asked | Implemented? | Gap |
|---|---|---|
| 12+ idle micro-animations | No (blink + breathing only) | **Add glance / yawn / smile / look-around triggers** |
| Rive state machine for face | No — procedural painter | Documented decision §1; acceptable |
| Notification reactions (KEEP) | No | **Not implemented**; either build opt-in summarized reactions or strike it from the spec |
| "Hey Pixel" hotword | No (push-to-talk) | Documented decision §6 |
| 3 character variants | ✅ `variant` drives 3 palettes + shape changes in `face.dart` (`_palettes[variant % len]`, body aspect per variant) | done |
| A new skill = 1 file + 1 register line | ✅ | proven by registry |

The only *functional* regressions against the brief's KEEP list are **idle animation variety**
and **notification awareness**. Both are additive and fit the existing architecture.

---

## 7. Bottom line

- **Parity** on the core loop: expressive face state machine, voice in/out, calendar reminders,
  proactive briefs, provider-agnostic LLM, boot-persistent background work.
- **PixelCompanion is ahead** on privacy surface (≈4 permissions vs 30, no ad ID, no camera,
  no social SDKs), APK size, offline usefulness, configurability (rename/variant/personality),
  and transparent network logging.
- **LOOI is ahead** on animation richness, always-on ambient interaction (VAD), and reacting to
  the phone's own notifications.
- Nothing in this comparison involves, or depends on, the physical robot.

### Recommended next steps (no robot)
1. Add 4–6 idle micro-animation triggers to the existing `CompanionState` machine
   (glance-left/right, yawn after 5 min idle, smile on success) — closes the biggest felt gap.
2. Ship an **opt-in** notification-reaction skill (summaries only, off by default) to restore
   the spec's KEEP item with a privacy default that matches our stance.
3. Evaluate an optional on-device VAD gate for hands-free turn-taking, keeping push-to-talk as
   the default.
4. Optional: make the 3 variants more distinct than palette/shape (distinct eye & mouth styles).
