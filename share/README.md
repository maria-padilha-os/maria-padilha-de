# Shared data

`emojis.txt` is the emoji/glyph picker data, copied unchanged from the
Caelestia CLI v1.1.3 (`data/emojis.txt`, GPL-3.0, like the shell this desktop
descends from). It ships here so `bin/padilha-emoji` needs no network and no
Python.

To regenerate it, copy `data/emojis.txt` from the Caelestia CLI source at the
pin in `upstream.json` over this file unchanged. Fetching is a release-time
job; the picker only reads what is on disk.
