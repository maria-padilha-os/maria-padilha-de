# Maps

An OpenStreetMap viewer and place search for the Maria Padilha desktop, bundled
as an extension.

- 3x3 raster tile grid, starting at Porto Alegre (`-30.0346, -51.2177`) at
  zoom 12. Drag to pan; `+`/`−` and the mouse wheel zoom between 3 and 18.
- Search uses Nominatim and shows up to five results; clicking a result
  re-centers the map. Search only runs when the user submits the field — the
  only network traffic at startup is the nine initial tiles.
- All colours come from `api.colours.palette` (the `Colours` singleton) and
  spacing/typography from `Tokens`; the attribution is always visible.

## Files

| file | role |
| --- | --- |
| `extension.json` | manifest |
| `Tab.qml` | dashboard tab entry, 560×360 |
| `Widget.qml` | the map, search field, results and controls |

Install by copying this directory to `~/.config/padilha/extensions/maps`, then
enable it under Settings → Extensions → **Show in the top panel**.

## Data sources and limits

- Tiles: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, © OpenStreetMap
  contributors. Only the nine tiles around the centre are requested; there is
  no prefetching or bulk download. Respect the
  [tile usage policy](https://operations.osmfoundation.org/policies/tiles/).
- Search: Nominatim, up to five results. Requests are user-triggered and
  throttled to one every 1.1 seconds to match the
  [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/).
  Nominatim rejects Qt's stock User-Agent with HTTP 403, so the extension sets
  an identifying User-Agent header itself. No API key is used.
- No offline map cache: Qt caches recently loaded tile images only for the
  current session, and search needs network access. Standard 256 px tiles are
  used (no HiDPI variants).

## OpenStreetMap policy compliance

- Tile requests identify the app:
  `Padilha-Maps/1.0 (+https://github.com/maria-padilha-os/maria-padilha-de)`.
- Tiles are cached under `$XDG_CACHE_HOME/caelestia/maps/<z>/<x>/<y>.png`
  (`~/.cache/caelestia/maps/` by default); a cached tile is never refetched by
  a pan, zoom or shell restart.
- Only the nine tiles of the visible 3x3 grid are requested, and only while the
  Maps tab is the selected tab. Nothing is prefetched.
- Requests are staggered instead of fired as a burst.
- The "© OpenStreetMap contributors" credit links to
  https://www.openstreetmap.org/copyright.
- Nominatim search sends the same identifying User-Agent, is user-triggered only,
  and is throttled to one request per 1.1 s.
