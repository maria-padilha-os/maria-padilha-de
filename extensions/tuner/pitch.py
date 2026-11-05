#!/usr/bin/env python3
"""Estimate the pitch of one guitar note from raw PCM on stdin.

Input: 4096 samples of signed 16-bit little-endian mono PCM at 22050 Hz
(8192 bytes).  The stream is windowed with a Hann window and scanned with the
Goertzel algorithm from 60 Hz to 500 Hz in 1 Hz steps.  The strongest bin is
refined with parabolic interpolation, converted to the nearest equal-tempered
note (A4 = 440 Hz), and printed as a single JSON line.

Silence (or too little input) prints {"freq":0,"note":"","cents":0,"rms":0}.
Standard library only.
"""

import json
import math
import struct
import sys

SAMPLE_RATE = 22050
SAMPLE_COUNT = 4096
BYTE_COUNT = SAMPLE_COUNT * 2

MIN_FREQ = 60
MAX_FREQ = 500

# Gate on the RMS of the unwindowed signal.  Below this the analysis is not
# meaningful and the UI shows "silence" instead of a random noise bin.
SILENCE_RMS = 0.01
# Also require the winning bin to carry real energy.  Broadband room noise can
# pass the RMS gate while spreading its energy over hundreds of bins.
SILENCE_AMPLITUDE = 0.01

NOTE_NAMES = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")


def silence() -> dict:
    return {"freq": 0, "note": "", "cents": 0, "rms": 0}


def read_samples() -> list[float]:
    raw = sys.stdin.buffer.read(BYTE_COUNT)
    usable = len(raw) - (len(raw) % 2)
    if usable < BYTE_COUNT:
        return []
    values = struct.unpack(f"<{SAMPLE_COUNT}h", raw[:BYTE_COUNT])
    return [value / 32768.0 for value in values]


def hann_window(count: int) -> list[float]:
    denominator = count - 1
    return [0.5 - 0.5 * math.cos(2.0 * math.pi * i / denominator) for i in range(count)]


def goertzel_power(samples: list[float], coefficient: float) -> float:
    """Return the (unnormalised) power of one DFT bin."""
    s1 = 0.0
    s2 = 0.0
    for sample in samples:
        s0 = sample + coefficient * s1 - s2
        s2 = s1
        s1 = s0
    power = s1 * s1 + s2 * s2 - coefficient * s1 * s2
    return max(0.0, power)


def detect(samples: list[float], windowed: list[float]) -> dict:
    rms = math.sqrt(sum(value * value for value in samples) / len(samples))
    if rms < SILENCE_RMS:
        return silence()

    powers = []
    for frequency in range(MIN_FREQ, MAX_FREQ + 1):
        coefficient = 2.0 * math.cos(2.0 * math.pi * frequency / SAMPLE_RATE)
        powers.append(goertzel_power(windowed, coefficient))

    peak_index = max(range(len(powers)), key=powers.__getitem__)
    peak_frequency = float(MIN_FREQ + peak_index)

    # For a Hann-windowed sine the peak bin magnitude is A * N / 4.
    peak_amplitude = 4.0 * math.sqrt(powers[peak_index]) / len(windowed)
    if peak_amplitude < SILENCE_AMPLITUDE:
        return silence()

    # Parabolic interpolation over the magnitude of the peak and its two
    # neighbours gives sub-Hz resolution from the 1 Hz scan.
    if 0 < peak_index < len(powers) - 1:
        left = math.sqrt(powers[peak_index - 1])
        centre = math.sqrt(powers[peak_index])
        right = math.sqrt(powers[peak_index + 1])
        denominator = left - 2.0 * centre + right
        if abs(denominator) > 1e-12:
            offset = 0.5 * (left - right) / denominator
            if -0.5 <= offset <= 0.5:
                peak_frequency += offset

    midi = round(69 + 12.0 * math.log2(peak_frequency / 440.0))
    note = NOTE_NAMES[midi % 12] + str(midi // 12 - 1)
    target = 440.0 * 2.0 ** ((midi - 69) / 12.0)
    cents = 1200.0 * math.log2(peak_frequency / target)
    rounded_cents = round(cents, 1)
    if rounded_cents == 0:
        rounded_cents = 0.0

    return {
        "freq": round(peak_frequency, 2),
        "note": note,
        "cents": rounded_cents,
        "rms": round(rms, 3),
    }


def main() -> None:
    try:
        samples = read_samples()
        if not samples:
            print(json.dumps(silence()))
            return
        window = hann_window(len(samples))
        windowed = [sample * gain for sample, gain in zip(samples, window)]
        print(json.dumps(detect(samples, windowed)))
    except Exception:  # noqa: BLE001 - any failure must still yield a JSON line
        # Never leave the UI without a parsable line.
        print(json.dumps(silence()))


if __name__ == "__main__":
    main()
