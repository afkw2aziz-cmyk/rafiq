# LOOI — Clean-Room Functional Spec

> Source of truth: official APK `com.TangibleFuture.looiRobot` v2.9.3 (versionCode 57),
> pulled from the owner's own Pixel 6 on 2026-11-11.
> Method: static inspection only (manifest, resource table, asset inventory, DEX package/class
> names, native libraries). No code was executed, decompiled output was not copied, and no
> assets, strings, audio, or art are redistributed with this project.
>
> **This document contains functional observations and abstractions only.** It is input for an
> original implementation, not a port.

---

## 1. What the app actually is

The APK is a **native Android app (Kotlin + Jetpack Compose)**, not Flutter/React Native.
It is the companion/controller for a physical desktop robot:

| Evidence | Interpretation |
|---|---|
| `assets/inspireface/*` | On-device face detection/recognition (InspireFace SDK) |
| `assets/mlkit_facemesh/*`, `mlkit_odt_localizer` | Face mesh / object detection for interaction |
| `assets/silero_vad.onnx` | Voice activity detection (always-on mic pipeline) |
| `libpag` + `assets/LooiData/**/*.pag` (843 MB split) | PAG vector animation bundles for the robot's face/expressions |
| Bluetooth / Wi-Fi permissions + scanning | Robot pairing and command channel |
| `BIND_NOTIFICATION_LISTENER_SERVICE` | Reads phone notifications to "react" to them |
| `READ_CALENDAR` / `WRITE_CALENDAR` | Calendar-aware reminders |
| CAMERA + RECORD_AUDIO | Sees and hears the room |
| ShareSDK / Tencent / Weibo entries | Chinese social login & sharing SDKs |

**Implication for PixelCompanion:** the robot link (Bluetooth servo commands, firmware
updates, the 843 MB animation pack) is hardware-bound and out of scope. What transfers is the
*interaction model*: an expressive face, voice-first control, proactive reminders, calendar
awareness, and a personality layer.

---

## 2. Screen flow (observed / inferred)

```
Launch
  └─ Account & permissions (notifications, mic, camera, calendar)
       └─ Robot discovery / pairing ──► (hardware only — DROP)
            └─ Home / idle face
                 ├─ Voice interaction (wake → listen → think → speak)
                 ├─ Chat history
                 ├─ Calendar & reminders
                 ├─ Notification reactions
                 ├─ Settings (voice, face, language, privacy)
                 └─ Firmware / device settings ──► (DROP)
```

For PixelCompanion the phone replaces the robot, so pairing/firmware screens collapse into a
single **onboarding** step that only asks for the permissions the enabled skills need.

## 3. UI component inventory

| Component | Observed behaviour | Our abstraction |
|---|---|---|
| Face canvas | Full-bleed expressive face, driven by animation state, not a static image | `CompanionFace` — procedural painter, 8 states |
| Conversation bubble | Short, large-type replies near the face | `SpeechBubble` overlay |
| Mic affordance | Push-to-talk plus VAD-driven listening | Mic FAB + `SttService` |
| Skill cards | Feature tiles (calendar, reminders, chat, stories) | `SkillManifest` cards in Settings |
| Reminder cards | Time + title + spoken delivery | `ReminderSkill` list |
| Settings panel | Voice, language, personality, privacy, device | `SettingsScreen` with per-skill permission view |
| Privacy / data screen | Lists what leaves the device | `Network activity` + per-skill disclosure |

## 4. Animation triggers (functional model)

The face reacts to app state rather than being a video loop:

| State | Trigger | Behaviour |
|---|---|---|
| `idle` | no interaction | blink every 2–6 s, breathe, occasional glance/yawn |
| `listening` | mic active | eyes widen, pupils track, halo pulse |
| `thinking` | request dispatched | eyes look up/away, orbiting dots |
| `speaking` | TTS active | mouth amplitude follows speech, nod on sentence end |
| `happy` | successful skill result | squint + smile + bounce |
| `sad` | error / failed permission | eyes lower, mouth down |
| `surprised` | new notification / alert | eyes open wide, antenna pop |
| `sleeping` | idle > 5 min / DND / bedtime | closed eyes, slow breathing, "z" |

We reproduce this as a **state machine driven by app events**, not copied art or timings.

## 5. Audio model

- Wake/interaction gate via VAD, then speech-to-text, then LLM, then TTS.
- Short non-verbal cues (chime on wake, soft error tone) — we synthesise original tones.
- Speech is interruptible: speaking stops when the user starts talking.

## 6. External integrations observed

- Calendar read/write (system CalendarProvider).
- Notification listener (reacts to incoming notifications).
- Cloud LLM/chat backend (chat is server-mediated; no provider key ships in the APK).
- Weather/clock/story content delivered from backend.
- Social login/sharing (China-centric) — irrelevant to us.

## 7. KEEP vs DROP

**KEEP (reimplemented originally)**
1. Expressive face state machine.
2. Voice-first loop: listen → think → speak, interruptible.
3. Proactive reminders tied to calendar/time.
4. Notification awareness (opt-in, summarized, never auto-read by default).
5. Personality presets and user-renameable companion.
6. Privacy screen listing every network egress.

**DROP**
1. Bluetooth/robot servo protocol and pairing.
2. `LooiData` PAG animation packs (843 MB) and all LOOI art/audio.
3. Firmware update flow.
4. Camera-based face recognition (unnecessary for a phone companion; privacy cost).
5. Chinese social SDKs.
6. Any copied string, icon, sound, or layout.

## 8. Clean-room statement

- No LOOI code, resources, fonts, sounds, or artwork are included in this repository.
- The character is an original geometric mascot drawn procedurally in Flutter.
- UI text is original (Arabic/English) and not extracted from the APK.
- The APK itself is stored outside the project (`looi_backup/`) and is not redistributed.
