# Bundled extensions

These ship with Maria Padilha and are installed to
`/usr/lib/maria-padilha/share/extensions` by `install.sh` and the package.
The shell still reads the pre-rename `/usr/lib/lilith/share/extensions` while
that tree exists. Settings → Extensions lists them and toggles their tab in the
top panel.

| id | what it does | tab size |
| --- | --- | --- |
| `calculator` | qalc front-end with history | 360×220 |
| `maps` | OpenStreetMap tiles, pan/zoom and Nominatim search | 560×360 |
| `stopwatch` | start/stop, laps, reset | 340×230 |
| `translator` | MyMemory translation between nine languages | 480×280 |
| `tuner` | microphone guitar tuner (Goertzel pitch detection, reference tones) | 420×260 |

To try the checkout copies before installing:

```sh
mkdir -p ~/.config/padilha/extensions
cp -r extensions/calculator extensions/maps extensions/stopwatch \
      extensions/translator extensions/tuner ~/.config/padilha/extensions/
```

User extensions in `~/.config/padilha/extensions` override bundled ones with the
same id. The old `~/.config/lilith/extensions` is read as a fallback during the
transition.
