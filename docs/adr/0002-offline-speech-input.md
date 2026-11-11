---
layout: default
title: "ADR 0002: Offline speech input"
---

# ADR 0002 — Offline speech input (spike report)

- **Status:** Proposed — research and a throwaway capture test only. No
  microphone dependency, model download, keybind, package change, or shell UI
  is part of this record.
- **Date:** 2026-11-11
- **Owner:** `maria-padilha-de` repository owner
- **Reviewers:** coordinator and the security reviewer for the desktop
- **Supersedes:** none
- **Related:** [ADR 0001](0001-built-in-ai-assistant.html),
  [Assistant home access](../assistant.html), `ARCHITECTURE.md`, `SECURITY.md`,
  [capture spike](https://github.com/maria-padilha-os/maria-padilha-de/blob/main/tools/voice-capture-spike.sh),
  [capture contract test](https://github.com/maria-padilha-os/maria-padilha-de/blob/main/tests/voice/run.sh)

## 1. Context

The assistant is text-only. A microphone would make it usable while the user is
away from the keyboard, but it adds a new privacy surface, a new CPU consumer,
and a model that has to be obtained and updated. This spike answers four
questions before any dependency is added:

1. Which offline recogniser fits this desktop: whisper.cpp, sherpa-onnx, or
   Vosk?
2. Can PipeWire capture be made opt-in and push-to-talk, with no always-on
   listener?
3. Does recognition run locally, and is any cloud fallback acceptable?
4. What has to be true before the assistant UI is wired to a microphone?

Constraints from the repository and the task:

- Wayland/Hyprland, Quickshell, Arch packaging, and no root requirement.
- No always-on listening, no wake word, no background recording.
- No audio upload, no committed audio samples, and no audio left behind by the
  test.
- Do not integrate the final UI until this report is reviewed.

The target laptop used for the local measurements is an AMD Ryzen 3 7320U
(4 cores / 8 threads, 7.1 GiB RAM, Linux 7.3, Manjaro/Arch-family). The agent
container had no reachable PipeWire server (`pw-cli info 0` failed), so the
capture prototype was exercised with a stubbed `pw-record`, not a real
microphone. That limitation is repeated in §4 and §6.

## 2. Decision (proposed)

**D1 — Recognition is local-only.** The default and the only supported mode in
v1 is on-device inference. No audio leaves the machine for recognition. There is
no automatic cloud fallback: if the local model fails, the assistant reports the
failure instead of silently uploading the utterance. A future cloud option
would be a separate, explicit per-utterance choice, never a fallback (see §5).

**D2 — Push-to-talk only.** The microphone opens on an explicit user action and
closes on release/stop, with a hard maximum. There is no wake word, no
voice-activity listener, no "record while the panel is open", and no background
capture. The capture file is temporary, mode `0700`/`0600`, and deleted on exit.

**D3 — v1 recogniser: whisper.cpp.** Use the official Arch `whisper-cpp`
package and a quantised GGML model. The proposed default is the multilingual
`base` model (q5_1, ~57 MiB) for language coverage; `base.en` is the default for
an English-only install. `small` (q5_1, ~181 MiB) is an opt-in accuracy upgrade,
not the default. The model is downloaded only after explicit consent, with a
pinned checksum, into the user's data directory; it is not bundled in this
repository or in the package.

Why whisper.cpp:

- It is in Arch **Extra** (`whisper-cpp` 1.9.5-1), so the base package can
  depend on it without adding an AUR requirement.
- MIT-licensed code and weights, broad language coverage, and text with casing
  and punctuation.
- On the target laptop, `base.en` q5_1 processed 11 s of audio in ~2.2 s
  (RTF ~0.20) with ~219 MiB peak RSS. That is fast enough for push-to-talk.
- It is the lowest-risk dependency to review: one official package, one model
  file, no Python runtime, no service, no daemon.

**D4 — sherpa-onnx is the technical runner-up, not a v1 dependency.** It had the
best accuracy/latency combination in the same-corpus benchmark and in the local
decode measurement, and it supports streaming. It is AUR-only in this
distribution, adds `onnxruntime`, and its best models have separate licences and
formats. Revisit it if it enters the official repositories, if the project is
willing to vendor a pinned build, or if the review decides AUR is acceptable.
The Arch `whisper-cpp` package also ships `parakeet-cli`; Parakeet could provide
sherpa-class accuracy without AUR. In this spike the packaged 1.9.5 build
aborted while loading the current `ggml-org/parakeet-GGUF` v3 model, so that path
is explicitly **unproven** and not part of the recommendation.

**D5 — Vosk is not selected.** It has the smallest CPU footprint and a streaming
API, but published accuracy is materially lower, small models do not restore
casing or punctuation, and push-to-talk does not need partial streaming. Its
official Arch package is a point in its favour, but not enough to outweigh the
accuracy gap for assistant dictation.

**D6 — No UI integration before review.** This branch adds a report, a
throwaway capture script, and a contract test. It does not touch `shell/`, the
keybinds, `install.sh`, `packaging/PKGBUILD`, or any user-facing assistant path.

## 3. Comparison

### 3.1 Summary

| | whisper.cpp | sherpa-onnx | Vosk |
| --- | --- | --- | --- |
| Runtime | C/C++ + ggml | C++ + onnxruntime | C++/Kaldi |
| Licence | MIT (code and Whisper weights) | Apache-2.0 (runtime); model licences vary | Apache-2.0 (runtime/models mostly) |
| Arch packaging | **Extra** `whisper-cpp` 1.9.5-1 | **AUR only** `sherpa-onnx` 2.0.1-1 (or `-bin`) | **Extra** `vosk-api` 0.3.50-7 |
| Model size, small | 57 MiB (base q5_1), 181 MiB (small q5_1) | 68 MiB (Zipformer en int8), ~631 MiB (Parakeet 0.6B int8) | 40 MiB (small en), 128 MiB (lgraph), 1.8 GiB (big en) |
| Peak RSS, measured | 219 MiB (base), 484 MiB (small) | 275 MiB (Zipformer) | 198 MiB (small) |
| Accuracy, published | 5.12 % base / 3.33 % small (multilingual, LS test-clean); 4.16 % / 3.09 % English-only | 3.18 % Zipformer; 1.69–1.97 % Parakeet (LS test-clean) | 9.85 % small en; 5.69 % big en (LS test-clean) |
| Decode latency, measured | RTF ~0.20 (base), ~0.56–0.63 (small) | RTF ~0.021 (Zipformer decode; 2–3 s cold model load) | RTF ~0.11–0.14 (small) |
| Text formatting | Case + punctuation | Zipformer: uppercase, no punctuation; Parakeet: case + punctuation | Usually lowercase, no punctuation in small models |
| Streaming | File/CLI; `whisper-stream` example | Yes, first-class | Yes, first-class |
| Verdict | **v1 default** | Best raw accuracy/latency; packaging blocks v1 | Not selected |

### 3.2 Accuracy evidence

The numbers below come from different test sets and normalisation, so they are
directional, not a single leaderboard. The same-corpus CPU benchmark is the most
useful comparison because it ran all three families on the same LibriSpeech
utterances with the same WER script.

**Same-corpus CPU benchmark** (1,089 LibriSpeech utterances, CPU-only; Whisper
via `faster-whisper` int8, sherpa models int8):

| Backend | WER | RTF |
| --- | ---: | ---: |
| sherpa-onnx Parakeet TDT 0.6B v2 int8 | 1.97 % | 0.0415 |
| sherpa-onnx Zipformer EN 2023-06-26 | 3.18 % | 0.0533 |
| Whisper (small, faster-whisper int8) | 4.71 % | 0.2767 |

Source: [bagustris/cpu-asr-benchmark](https://github.com/bagustris/cpu-asr-benchmark).
The README notes that the sherpa RTF includes simulated streaming overhead and
that Whisper warm-up is excluded.

**Published model-level numbers:**

| Model | WER (LibriSpeech test-clean) | Source |
| --- | ---: | --- |
| Whisper tiny / base / small, multilingual | 7.53 % / 5.12 % / 3.33 % | [transcribe.cpp Whisper table](https://github.com/handy-computer/transcribe.cpp/blob/main/docs/models/whisper.md) (Q8_0) |
| Whisper tiny.en / base.en / small.en | 5.72 % / 4.16 % / 3.09 % | same |
| Vosk small en-us 0.15 | 9.85 % | [Vosk model list](https://alphacephei.com/vosk/models) |
| Vosk en-us 0.22 | 5.69 % | same |
| Vosk en-us 0.22-lgraph | 7.82 % | same |
| Parakeet TDT 0.6B v2 | 1.69 % | [NVIDIA model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2) |
| Parakeet TDT 0.6B v3 (25 European languages) | not re-measured here | [GGUF model card](https://huggingface.co/ggml-org/parakeet-GGUF) |

The independent benchmark's Whisper number (4.71 %) is higher than the
published `small.en` number (3.09 %) because the split, text normalisation, and
decoding differ. Treat the ranking as the signal, not the absolute percentages.

### 3.3 Local same-sample sanity check

This is deliberately small: one 11.0 s, 16 kHz mono public sample
(`whisper.cpp/samples/jfk.wav`), four threads where the tool supports it. It is
not an accuracy benchmark; it is a latency and packaging sanity check on the
target laptop. Packages were extracted into `.scratch` rather than installed.
Wall time includes process startup and model load; decode/RTF is the tool's own
timing. Peak RSS is the child process high-water mark.

| Engine / model | Disk | Peak RSS | Model load | Decode / total | RTF | Transcript |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| whisper.cpp `base.en` q5_1 | 57 MiB | 219 MiB | 0.06 s | 2.16–2.20 s | 0.20 | exact, case + punctuation |
| whisper.cpp `small.en` q5_1 | 182 MiB | 484 MiB | 0.12–0.20 s | 6.20–6.87 s | 0.56–0.63 | exact, case + punctuation |
| sherpa-onnx Zipformer EN int8 | 68 MiB | 275 MiB | 2.06–2.76 s | 0.230–0.237 s | 0.021–0.022 | exact words, uppercase, no punctuation |
| Vosk small en-us 0.15 | 68 MiB unzipped (40 MiB zip) | 198 MiB | 0.49 s | 1.19–1.53 s | 0.11–0.14 | one error: “as not” instead of “ask not” |

Notes:

- sherpa-onnx's wall time was 2.36–3.09 s because the CLI rebuilds the recogniser
  on every process start. A resident recogniser would decode the same clip in
  ~0.23 s. Whisper's model load is small, so its decode time dominates.
- The Vosk transcript is lowercase and unpunctuated; the single word error is
  anecdotal but consistent with its published WER.
- For a typical 5 s push-to-talk utterance, the measured RTF projects to roughly
  1.0 s for Whisper base, 2.8–3.2 s for Whisper small, 0.1 s of decode for
  sherpa (plus cold load), and 0.6 s for Vosk. Add key handling and any silence
  trimming on top.
- The target laptop is weaker than the machines in most published benchmarks,
  which is why this local check matters more than the absolute vendor numbers.

### 3.4 Model size and CPU use

Whisper.cpp's GGML files are the easiest to reason about: `tiny` 75 MiB,
`base` 142 MiB, `small` 466 MiB in F16, or 31/57/181 MiB in q5_1. Quantisation
roughly preserves WER, reduces disk and memory, and usually improves CPU speed.
The `base` model measured ~219 MiB RSS and ~2.2 s per 11 s of audio; `small`
measured ~484 MiB and 6.2–6.9 s. Both are CPU-only and use AVX2 on this laptop.

Vosk's small model is the lightest in memory (about 200 MiB measured, vendor
says about 300 MiB) and it streams incrementally, which is valuable for live
partials. Big Vosk models are server-class (1.8 GiB model, up to 16 GiB memory
per Vosk's documentation). In this sample its total decode time was still
higher than sherpa's (1.2–1.5 s versus 0.23 s), so its advantage is streaming
behaviour and a small footprint, not raw throughput; its accuracy is the
weakest.

sherpa-onnx is the most efficient decoder once loaded: ~275 MiB RSS and ~0.23 s
per 11 s for the 68 MiB Zipformer. Its cold start is the trade-off: 2–3 s to
create the recogniser. A long-lived assistant process should keep it warm if it
is chosen; a per-utterance CLI should not.

All three are CPU-only in this design. GPU paths exist (Vulkan/CUDA/ROCm for
whisper.cpp, providers for sherpa-onnx, not needed for Vosk) but are out of
scope and would add driver-specific packaging.

### 3.5 Packaging on Arch

| Package | Repository | Installed size | Notes |
| --- | --- | ---: | --- |
| [`whisper-cpp`](https://archlinux.org/packages/extra/x86_64/whisper-cpp/) 1.9.5-1 | Extra | 3.4 MB | Depends on `ffmpeg` and `ggml`. Provides `whisper-cli`, `whisper-server`, `whisper-bench`, `parakeet-cli`, libraries, headers. Models are separate. |
| [`ggml`](https://archlinux.org/packages/extra/x86_64/ggml/) 0.29.0-1 | Extra | — | CPU backend plugins live in `/usr/lib/ggml`; the package uses the system ggml build. |
| [`sherpa-onnx`](https://aur.archlinux.org/packages/sherpa-onnx) 2.0.1-1 | AUR | — | Source build; depends on `jack` and `onnxruntime`; 3 votes on 2026-11-11. The AUR page warns that an `onnxruntime` upgrade requires a rebuild. |
| [`sherpa-onnx-bin`](https://aur.archlinux.org/packages/sherpa-onnx-bin) 2.0.1-1 | AUR | — | Prebuilt x86_64/ARM binaries; 0 votes; adds a prebuilt-binary supply-chain review. |
| [`onnxruntime-cpu`](https://archlinux.org/packages/extra/x86_64/onnxruntime-cpu/) 1.29.0-3 | Extra | — | CPU-only runtime; official, but the AUR sherpa package is still the missing link. |
| [`vosk-api`](https://archlinux.org/packages/extra/x86_64/vosk-api/) 0.3.50-7 | Extra | 25.7 MB | Apache-2.0; split `python-vosk`; optional Java bindings. Models are not in the official package. |

Model acquisition is the other half of packaging. None of the three ships its
useful models in the official Arch package. The proposed model manager would:

- download only on an explicit user action, never at first launch silently;
- pin a SHA-256 per model and verify it before use;
- store under `$XDG_DATA_HOME/padilha/models` with mode `0700`, file mode `0600`;
- let the user delete a model; deleting it disables voice input cleanly;
- never put a model or audio in this repository or in `packaging/`.

This is a design, not implemented in this spike.

## 4. Prototype: PipeWire capture and push-to-talk

`tools/voice-capture-spike.sh` is a throwaway, uninstalled capture test. It is
not referenced by the shell, `install.sh`, or `packaging/PKGBUILD`.

What it does:

1. Refuses to run without `--i-understand-this-records-audio`.
2. Checks for `pw-record`, `pw-cli`, and `python3`.
3. Connects with `timeout 5 pw-cli info 0`; if PipeWire is not reachable it
   exits before opening any device.
4. Creates a private temporary directory with `mktemp -d` and mode `0700`.
5. Waits for Enter. Only then starts `pw-record` with raw s16, 16 kHz, mono and
   a hard `--sample-count` cap (1–30 s, default 10 s).
6. Waits for Enter again or the sample-count cap. A timeout is expected; EOF
   also stops the capture. On `INT`/`TERM` it kills the recorder in the exit
   trap.
7. Analyses the raw samples locally (duration, peak dBFS, RMS dBFS), deletes
   the file, then removes the temporary directory.

There is no `curl`, `wget`, socket, or other upload path in the script. A test
fails if one appears. The recording is never started in the background without
the foreground Enter confirmation, and it cannot outlive the script: the trap
kills and reaps the child on every exit path.

The terminal flow is press-to-start / press-to-stop, not hold-to-talk. That is
the smallest safe prototype in a shell. A compositor binding would map key-down
to the same start step and key-up to the stop step in a follow-up; that binding
is deliberately **not** added here, because it would be an integration decision.
The capture script is the piece that can be reused; the key handling belongs in
the reviewed UI change.

`tests/voice/run.sh` runs the script with stub `pw-cli`/`pw-record` binaries, so
the default test suite never touches a microphone. It checks:

- the opt-in gate and the no-recorder-on-refusal rule;
- the out-of-range duration guard;
- fail-closed behaviour when PipeWire is unreachable;
- the raw 16 kHz mono capture arguments and the hard sample cap;
- temp-file deletion after a successful run;
- no upload command in the script;
- no tracked or untracked audio sample in the checkout.

The suite is part of `tests/all.sh`.

**Not verified here:** a real PipeWire session, the default source selection,
Bluetooth headset latency, echo cancellation, and whether the target microphone
needs a non-default `--target`. The container had no PipeWire server. The script
refuses in that case, which is the intended fail-closed behaviour, but a real
session test is required before the report is accepted.

## 5. Privacy trade-off

### Local-only (chosen)

What stays local: the raw audio, the model, the transcript before it is handed
to the assistant, and every inference. Nothing is sent to a provider for
recognition. The design works offline, has no per-word cost, and does not depend
on a provider's retention policy, terms change, or jurisdiction. A network
failure cannot turn into an accidental upload because there is no upload path.

What it costs:

- **Disk and memory:** 57–181 MiB of model, 219–484 MiB RSS for the Whisper
  options measured here. A model download is a one-time network use; the model
  itself is then local.
- **CPU and battery:** recognition is a short CPU burst on push-to-talk, but
  `small` took 6–7 s for 11 s of audio on this laptop. `base` is the better
  default for a low-power machine; `small` should be an explicit choice.
- **Accuracy:** a local `base` model is below cloud large-model accuracy on
  accents, noisy rooms, proper nouns, and low-resource languages. It can
  hallucinate on silence or noise. Push-to-talk, a maximum duration, an empty
  transcript guard, and a visible "no speech detected" state are required.
- **Language coverage:** Whisper covers many languages, but quality varies.
  The multilingual `base` default is a compromise; a Portuguese or English
  choice should be a documented setting, not an assumption.
- **Failure mode:** if the model is missing or inference fails, voice input
  stops. That is preferable to a silent cloud fallback.

### Cloud fallback (not allowed in v1)

A cloud recogniser would likely improve accuracy for accented or noisy speech
and reduce local CPU, but it changes the threat model:

- Raw voice leaves the machine and may be retained, logged, reviewed, or used
  to improve a service. Voice is biometric-adjacent; it cannot be un-sent.
- The provider sees network metadata and possibly an account identity; the
  transcript may be stored on both sides.
- A "fallback" is especially dangerous because it can happen without the user
  noticing. An explicit opt-in is the only defensible form.

If cloud recognition is ever proposed, it must be a separate decision with at
least: off by default, a per-utterance confirmation (not a one-time global
switch), a visible indicator while audio is being sent, no automatic fallback,
no audio in logs or transcripts, a stated retention policy, a provider/key
model consistent with ADR 0001, and a permanent "never use cloud" setting. The
recommendation of this spike is **not** to add it.

Transcripts are a separate privacy surface. ADR 0001 already defaults assistant
history to off; voice input should not change that default. A transcript that is
persisted is text, not audio, but it still contains what was said.

## 6. Risks and open questions

| Risk | Why it matters | Mitigation / next check |
| --- | --- | --- |
| No live PipeWire test in this environment | The capture path is only proven against a stub | Run the script in a real session on the laptop; verify `pw-cli info 0`, source selection, levels, and deletion |
| Accuracy on this user's language/accent/names | LibriSpeech is read English, not assistant dictation | Build a small local evaluation set from consented speech, compare `base`/`small`/Parakeet, and do not commit the audio |
| Whisper hallucination on silence/noise | Short or empty clips can produce invented text | Hard duration cap, energy gate, empty-result guard, and a user-visible retry |
| Model download integrity | A corrupted or swapped model is hard to detect at runtime | Pin SHA-256, verify before load, fail closed, no auto-update |
| Model disk use | A full home or a small SSD can make downloads fail | Check free space, allow deletion, keep only the selected model |
| CPU/battery on the Ryzen 3 | `small` is 6–7 s per 11 s in this sample | Default to `base`; benchmark a 5 s utterance, not just the 11 s sample |
| Arch `whisper-cpp`/`ggml` ABI or model changes | The package ships `parakeet-cli` but the current Parakeet v3 GGUF aborted in this extracted-package test | Pin the package version; test the chosen model against the packaged CLI; do not rely on Parakeet until validated |
| AUR sherpa-onnx | AUR builds can lag `onnxruntime` and need rebuilds | Keep it out of v1; revisit only with an explicit packaging decision |
| Vosk model licensing/age | Small models are old and have no casing/punctuation | Not selected; do not add a second engine without a measured reason |
| Key handling and focus | A global keybind could fire in the wrong window or leave the mic open | Hold-to-talk/key-up stop, a hard timeout, and a visible recording indicator; do not add a keybind in this spike |
| Bluetooth/headset switching | PipeWire may select the wrong source or add latency | Test with the real devices; expose `--target` only as a manual option |

Open questions for review:

1. Is whisper.cpp `base` multilingual the right default, or should the first
   release be English-only `base.en` for the extra accuracy?
2. Is a 57 MiB model download acceptable as an opt-in, or should voice input
   stay behind a model-manager screen until the user chooses a size?
3. Does the review accept the AUR packaging risk for sherpa-onnx, or is the
   official package a hard requirement? If AUR is acceptable, sherpa-onnx is
   technically stronger.
4. Should the capture flow own silence trimming, or should the recogniser see
   the raw clip and decide? Trimming reduces hallucination but adds an audio
   processing dependency.
5. Where should the "recording" indicator live so it is visible but cannot be
   confused with an always-on listener?

## 7. Review gate and next steps

This report is the gate. Until it is reviewed:

- no `whisper-cpp`/`sherpa-onnx`/`vosk-api` entry in `packaging/PKGBUILD`;
- no model download at startup;
- no `shell/` microphone code, QML recorder, or global keybind;
- no change to `install.sh` or `packaging/apps.list`.

If the report is accepted, the follow-up change should, in order:

1. Add the chosen package as a dependency or optdepend and a model manager with
   checksums and deletion.
2. Wire a hold-to-talk key (key-down start, key-up stop) with a visible
   recording indicator and a hard timeout.
3. Add a real-session test for PipeWire capture, device selection, and cleanup.
4. Add the assistant integration only after 1–3 pass and the privacy copy is
   reviewed.

## 8. References

- whisper.cpp: <https://github.com/ggml-org/whisper.cpp> and
  <https://github.com/ggml-org/whisper.cpp/blob/master/models/README.md>
- whisper.cpp Parakeet CLI:
  <https://github.com/ggml-org/whisper.cpp/blob/master/examples/parakeet-cli/README.md>
- OpenAI Whisper and model card:
  <https://github.com/openai/whisper> and
  <https://github.com/openai/whisper/blob/main/model-card.md>
- Whisper paper: <https://arxiv.org/abs/2212.04356>
- transcribe.cpp Whisper WER/latency tables:
  <https://github.com/handy-computer/transcribe.cpp/blob/main/docs/models/whisper.md>
- sherpa-onnx: <https://github.com/k2-fsa/sherpa-onnx> and
  <https://k2-fsa.github.io/sherpa/onnx/>
- sherpa-onnx Arch packaging:
  <https://aur.archlinux.org/packages/sherpa-onnx> and
  <https://aur.archlinux.org/packages/sherpa-onnx-bin>
- Vosk: <https://github.com/alphacep/vosk-api> and
  <https://alphacephei.com/vosk/models>
- Same-corpus CPU ASR benchmark:
  <https://github.com/bagustris/cpu-asr-benchmark>
- Parakeet TDT 0.6B v2:
  <https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2>
- Parakeet GGUF models:
  <https://huggingface.co/ggml-org/parakeet-GGUF>
- Arch packages:
  <https://archlinux.org/packages/extra/x86_64/whisper-cpp/>,
  <https://archlinux.org/packages/extra/x86_64/vosk-api/>,
  <https://archlinux.org/packages/extra/x86_64/onnxruntime-cpu/>
- PipeWire `pw-record`:
  <https://docs.pipewire.org/page_man_pw-record_1.html>
