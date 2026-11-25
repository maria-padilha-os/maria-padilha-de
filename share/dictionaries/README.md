# Offline dictionaries

Language packs are StarDict trees: `pack.json` plus `dic/<name>/` with the
`.ifo`, `.idx` and `.dict.dz` files. The shell reads the pack for the system
language from `/usr/lib/maria-padilha/share/dictionaries/<language>` and from
`~/.local/share/padilha/dictionary/<language>`.

The bundled `pt` pack is the FreeDict Portuguese-English / English-Portuguese
dictionary (GPL-2.0-or-later, https://freedict.org/). Its copying terms are in
`pt/COPYING`.
