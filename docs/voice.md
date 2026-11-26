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
padilha-voice setup                      # download Piper + pt-BR voice
padilha-voice speak "Olá, Maria Padilha"  # queue speech
padilha-voice speak --wait "..."         # wait for this utterance
padilha-voice speak --no-interrupt "..." # append instead of replacing
padilha-voice stop                       # stop playback and clear the queue
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

- **Piper** (default): local VITS voice, currently `pt_BR-faber-medium` at
  22050 Hz, run from a private venv under
  `~/.local/share/padilha/voice`. Runtime memory is roughly 150–300 MB.
- **espeak-ng**: low-memory fallback if installed.

`padilha-voice setup` downloads the Piper wheel and voice model into the user's
data directory; it needs network access on first use but no root. Existing
assets are reused.

## Desktop integration

- The Assistant drawer has a speaker toggle beside Send. When enabled, only a
  completed assistant answer is spoken; tool output and streaming chunks are
  not.
- `session/systemd/user/padilha-voice.service` runs the daemon at login. The CLI
  can also start it on demand, so a desktop without systemd management still
  works.
- Speech input will use the same socket and queue contract; clients should
  treat `listen` as capability detection instead of assuming a microphone is
  available.

## Privacy

Audio is synthesized locally. No text or audio is sent to a network service by
the voice daemon. The setup command downloads public model assets only.
