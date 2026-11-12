# Session state — 2026 (PixelCompanion 1.4.0+5)

Where the project stands, so work can resume without re-deriving anything.

## Shipped and verified on device

| Feature | Evidence |
|---|---|
| Gemini chat | «why is the sky blue» → correct Arabic answer |
| AI news summary | Arabic bullets, not raw English headlines |
| US stocks (Yahoo) | `TSLA 390.84 USD ▲ +2.91%` |
| Al Jazeera + AI + GitHub + stocks digest | all four lines in one Arabic brief |
| Natural-language intent routing | «how much is tesla worth right now» → stock skill |
| Hourly digest scheduling | `kDigestTask`, hourly + settings switch |
| Idle micro-animations | 7 moods in `face.dart`, visually confirmed |

State at close: `versionName=1.4.0`, 29 tests passing, `flutter analyze` clean,
0 crashes, connected over Wi-Fi at `<device-ip>:5555`.

## Decisions worth remembering

- **`thinkingBudget: 0` in `lib/services/llm.dart`.** Gemini 2.5 spent the output
  budget on internal thinking and truncated replies at ~46 chars
  (`finishReason: MAX_TOKENS`). Do not remove this field.
- **Digest is registered before news.** `news_skill` used to claim the `digest`
  trigger and shadow the digest skill. `test/digest_route_test.dart` guards this.
- **Intent routing is Gemini-first with regex fallback**, gated by
  `settings.smartRouting` and skipped automatically when there is no key.
- **Saved `enabledSkills` do not pick up new skills.** Adding a skill may require
  clearing `shared_prefs/FlutterSharedPreferences.xml` on an existing install.
- **`adb input text` cannot type Arabic reliably** (throws
  `NullPointerException` without `%s` escaping, and often loses focus). Arabic was
  verified against the Gemini API directly, not through the device UI.

## Deferred / open

- **Character reference JSON** (`~/Downloads/character_reference.json`): it is a
  text-only image-generator spec, not an animation file, so it cannot replace
  `face.dart` as-is. Options were: regenerate a reference image from it, or port
  its face traits (large brown eyes, rosy cheeks, thick outlines) into the
  procedural face. Deferred by user decision.
- **60s stock price cache** to avoid Yahoo HTTP 429 on rapid repeats.
- **Release APK build** — debug APK is 158 MB; `--release` will be far smaller.
- **Arabic on-device testing** needs manual typing.

## Device notes

- Pixel 6, `19231FDF600013`, Android 17 (API 37), PIN lock persists.
- Wireless: `adb connect <device-ip>:5555`; re-run `adb tcpip 5555` over USB
  after a reboot.
- Notification access must be granted with:
  `adb shell cmd notification allow_listener com.ali.pixel_companion/com.ali.pixel_companion.PixelNotificationListener`
- Not a git repo; files live directly on disk.
