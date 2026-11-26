---
layout: default
title: Padilha voice service
---

`padilha-voice` is the desktop-neutral speech service. It owns one Unix
socket and one serialized speech queue, and plays through PipeWire. Clients
do not need Quickshell, Hyprland, GTK or Qt, so the same service can be used
by the Assistant drawer, another shell, a TUI or a settings panel.

## Commands

```sh
padilha-voice setup                      # Kokoro + Piper fallback + voice
padilha-voice speak "Olá, Maria Padilha"  # queue speech
padilha-voice speak --wait "..."         # wait for this utterance
padilha-voice speak --no-interrupt "..." # append instead of replacing
padilha-voice stop                       # stop playback and clear the queue
padilha-voice config                     # voice, speed and engine
padilha-voice set-speed 0.82             # warmer/slower
padilha-voice status
padilha-voice voices
```

`speak` with no text, or with `-`, reads UTF-8 from stdin, which keeps long
answers out of argv. Speech text is reduced to plain text before synthesis:
code fences, URLs, Markdown punctuation and extra whitespace are removed.

## Protocol

The socket is `$XDG_RUNTIME_DIR/padilha/voice.sock`, mode `0600`, with one JSON
object per line. It is intentionally small enough for any language or desktop
to implement.

```json
{"cmd":"speak","text":"Bom dia","interrupt":true}
{"cmd":"stop"}
{"cmd":"status"}
{"cmd":"listen"}
```

`speak` returns immediately with an id and the queue status; `stop` kills the
current player and clears queued speech. `listen` is reserved for the later
speech-input implementation and currently returns `stt_not_implemented` rather
than opening the microphone.

## Engines

- **Kokoro** (default): local Brazilian Portuguese female voice `pf_dora`,
  tuned to speed `0.82`. The int8 model is not used because the current
  Kokoro ONNX package feeds its `speed` tensor with the wrong dtype; the
  service applies the local float32 input fix when loading the voice.
- **Piper**: local fallback voice, `pt_BR-faber-medium` at 22050 Hz.
- **espeak-ng**: low-memory fallback if installed.

Kokoro adds roughly 0.8–1.2 GB resident memory when loaded. The service keeps
it loaded for low-latency answers; the machine has enough headroom for the
assistant, but not for several heavy tool jobs at once.

`padilha-voice setup` downloads the Kokoro runtime/model, the Piper fallback
and the voice data into the user's data directory; it needs network access on
first use but no root. Existing assets are reused. `padilha-voice config`
shows the saved voice and speed; `set-voice` and `set-speed` change them live.

## Desktop integration

- The Assistant drawer has a speaker toggle beside Send. When enabled, only a
  completed assistant answer is spoken; tool output and streaming chunks are
  not.
- `session/systemd/user/padilha-voice.service` runs the daemon at login. The CLI
  can also start it on demand, so a desktop without systemd management still
  works.
- `padilha-voice listen --events` is the speech-input/wake loop. It uses a
  local Whisper tiny model (`padilha-voice setup-wake`), an energy VAD, and a
  fuzzy Portuguese “Padilha” matcher. On a wake it emits `wake`; the Assistant
  opens and the next utterance is transcribed into the composer, never
  auto-sent.
- The wake listener is opt-in (Assistant → Wake word) and is disabled by
  default. Audio stays local.

## Privacy

Audio is synthesized locally. No text or audio is sent to a network service by
the voice daemon. The setup command downloads public model assets only.
