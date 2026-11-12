# Future integrations — rated

Rating legend: **D** = difficulty, **P** = privacy impact (L low → H high), **Pri** = priority
(P0 next release, P1 soon, P2 later, P3 maybe never).

| Idea | What it adds | APIs / deps | D | P | Pri | Notes |
|---|---|---|---|---|---|---|
| Smart home | Lights, scenes, "good night" routine | Home Assistant REST / Matter / Google Home | Medium | Medium | P0 | Home Assistant needs a local URL + token; Matter needs a commissioned fabric. Start read-only + scenes. |
| Widget mode | Character + next event on home screen | `home_widget` + AppWidgetProvider | Medium | Low | P0 | High perceived value, no new permissions. |
| LLM router | Gemini for general, Claude for code, GPT for math | `LLMRouter` policy + more providers | Easy | Medium | P0 | Interface already exists; policy is a settings table. |
| Email triage | Summarize unread important mail | Gmail API (read-only scope) | Hard | High | P1 | OAuth + restricted scope review; keep summaries on-device. |
| Focus / Pomodoro | Timer with character reactions | Local only | Easy | Low | P1 | Great fit for the face state machine. |
| Voice journaling | Speak → Markdown diary on device | STT + local file | Easy | Low | P1 | Zero cloud if on-device STT is used. |
| RSS / podcasts | Personal feed digest | `dart:xml` / feed APIs | Easy | Low | P1 | Reuses NewsSkill pipeline. |
| Health | Steps, hydration nudges | Health Connect | Medium | High | P2 | Permission-heavy, Play policy sensitive. |
| Crypto | Watchlist + thresholds | CoinGecko | Easy | Low | P2 | Reuses StockSkill UI. |
| Wear OS companion | Watch face + next reminder | Wear OS module | Hard | Low | P2 | Separate module, large scope. |
| Always-on face | Subtle face on AOD | `WallpaperService`/AOD APIs | Hard | Low | P3 | OEM-restricted; Pixel AOD not extensible for third-party apps. |
| Screen-off listening | Wake word with screen off | Licensed KWS + FGS mic | Hard | High | P3 | Battery and policy risk; defer. |
| Local LLM | Offline chat | llama.cpp / MediaPipe Gemma | Hard | Low | P3 | Measured ceiling on this Pixel 6: ~1.7B Q4, ~5 tok/s; ship as optional download, never bundled. |
| MCP server | Desktop Claude reads calendar/reminders | Embedded HTTP + MCP JSON-RPC | Medium | High | P2 | Powerful for power users; needs pairing token and local-only binding. |
| IFTTT / webhooks | Trigger plugs, Notion, etc. | Webhook URL + HMAC | Easy | Medium | P2 | Add an allow-list and a clear network log entry per call. |
