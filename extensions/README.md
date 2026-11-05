# Bundled extensions

These ship with Lilith and are installed to
`/usr/lib/lilith/share/extensions` by `install.sh` and the package. Settings →
Extensions lists them; **Show in the top panel** adds a dashboard tab.

| id | what it does | tab size |
| --- | --- | --- |
| `calculator` | qalc front-end with history | 360×220 |
| `maps` | OpenStreetMap tiles, pan/zoom and Nominatim search | 560×360 |
| `stopwatch` | start/stop, laps, reset | 340×230 |
| `translator` | MyMemory translation between nine languages | 480×280 |
| `tuner` | microphone guitar tuner (Goertzel pitch detection, reference tones) | 420×260 |

To try the checkout copies before installing:

```sh
mkdir -p ~/.config/lilith/extensions
cp -r extensions/calculator extensions/maps extensions/stopwatch \
      extensions/translator extensions/tuner ~/.config/lilith/extensions/
```

User extensions in `~/.config/lilith/extensions` override bundled ones with the
same id.
