# Bundled extensions

These ship with Maria Padilha and are installed to
`/usr/lib/maria-padilha/share/extensions` by `install.sh` and the package.
The shell still reads the pre-rename `/usr/lib/lilith/share/extensions` while
that tree exists. Settings → Extensions lists them and toggles their tab in the
top panel.

| id | what it does | tab size |
| --- | --- | --- |
| `calculator` | qalc front-end with history | 360×220 |
| `maps` | CARTO light/dark tiles, pan/zoom and Nominatim search | 560×360 |
| `stopwatch` | start/stop, laps, reset | 340×230 |
| `colour-picker` | sample a screen colour and copy HEX/RGB/HSL | 360×430 |
| `translator` | MyMemory translation between nine languages | 480×280 (min 360×280, fills the dashboard) |
| `tuner` | microphone guitar tuner (Goertzel pitch detection, reference tones) | 420×260 |
| `notes` | local plain-text notes (create, edit, delete) | 640×420 |
| `calendar` | local month view and events | 680×460 |
| `unit-converter` | offline length, mass, temperature, data and time conversion | 560×340 |

Each tab declares its preferred size and its `minimumWidth`/`minimumHeight`.
The dashboard clamps extension panels to those minimums, so a tab can shrink
without clipping its labels or actions. The bundled calculator, files, maps,
stopwatch, translator and tuner follow the
[widget design checklist](../docs/design-checklist.md).

The translator layout, compact behaviour and interaction checklist are in
[`docs/translator-layout-checklist.md`](../docs/translator-layout-checklist.md).

`notes`, `calendar` and `unit-converter` live in `share/extensions/` because
they keep their user data next to the other Padilha state:

- notes: `~/.local/share/padilha/notes/*.txt`
- calendar: `~/.local/share/padilha/calendar/events.json`

Both honour `XDG_DATA_HOME`. The dashboard scanner reads the checkout's
`share/extensions/` while developing and the installed copies under
`/usr/lib/maria-padilha/share/extensions` after installation.

| `system-monitor` | CPU, memory and load average | 520×360 |
| `pomodoro` | focus/break timer with desktop notifications | 420×340 |
| `disk-usage` | read-only mounted filesystem usage | 560×400 |

To try the checkout copies before installing:

```sh
mkdir -p ~/.config/padilha/extensions
cp -r extensions/calculator extensions/maps extensions/stopwatch \
      extensions/translator extensions/tuner extensions/colour-picker \
      ~/.config/padilha/extensions/
cp -r share/extensions/notes share/extensions/calendar \
      share/extensions/unit-converter ~/.config/padilha/extensions/

      extensions/translator extensions/tuner extensions/system-monitor \
      extensions/pomodoro extensions/disk-usage ~/.config/padilha/extensions/
```

User extensions in `~/.config/padilha/extensions` override bundled ones with the
same id. The old `~/.config/lilith/extensions` is read as a fallback during the
transition.
