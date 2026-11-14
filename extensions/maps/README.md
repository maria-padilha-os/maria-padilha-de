# Maps

A CARTO light/dark basemap viewer and Nominatim place search for the Maria
Padilha desktop, bundled as an extension.

- 3x3 raster tile grid, starting at Porto Alegre (`-30.0346, -51.2177`) at
  zoom 12. Drag to pan; `+`/`−` and the mouse wheel zoom between 3 and 18.
- The tile style follows the active palette: `light_all` in a light scheme and
  `dark_all` in a dark one (`api.colours.light`). The map frame uses the
  palette's surface colour, so the canvas reads as white or black while tiles
  load.
- Search uses Nominatim and shows up to five results; clicking a result
  re-centers the map. Search only runs when the user submits the field.
- All colours come from `api.colours.palette` (the `Colours` singleton) and
  spacing/typography from `Tokens`; attribution is always visible.

## Files

| file | role |
| --- | --- |
| `extension.json` | manifest |
| `Tab.qml` | dashboard tab entry, 560×360 |
| `Widget.qml` | the map, search field, results, controls and states |
| `MapStyle.js` | pure style selection, tile URL and cache-key helpers |

Install by copying this directory to `~/.config/padilha/extensions/maps`, then
enable it under Settings → Extensions → **Show in the top panel**.

## Configuring the CARTO key

CARTO's raster basemaps need a free API key. The extension never contains one
and never writes one; supply it at runtime with either:

```sh
# Preferred: environment, for the shell session only.
export PADILHA_MAPS_CARTO_KEY='YOUR_KEY'
```

or a user-only config file (quotes are optional):

```ini
# ~/.config/padilha/maps.conf
carto_key = YOUR_KEY
```

`XDG_CONFIG_HOME` is honoured. The environment variable wins when both are
set. The file is outside this checkout, so it is never committed; keep it
private with `chmod 600 ~/.config/padilha/maps.conf`. Request a key at
<https://carto.com/basemaps/apikey/>. Use an unrestricted key (or a key that
allows native clients): CARTO keys restricted to a website send no `Referer`
from a desktop app and get HTTP 403. If the key is missing, invalid or
restricted, the extension falls back to standard OpenStreetMap tiles and shows
that state instead of a blank canvas.

## Data sources and limits

- Tiles (primary): CARTO raster basemaps,
  `https://basemaps.cartocdn.com/rastertiles/{light_all|dark_all}/{z}/{x}/{y}.png`.
  Data © OpenStreetMap contributors, tiles © CARTO. When the CARTO style is in
  use both credits are visible on the map and link to the
  [OSM copyright](https://www.openstreetmap.org/copyright) and
  [CARTO attribution](https://carto.com/attribution/) pages.
- CARTO free tier: non-commercial use is free up to **5 million tile requests
  per calendar month**; commercial use is free up to **1 million**. Above
  those limits a paid plan is required, and keys are per-customer and must not
  be shared. See the
  [CARTO Basemaps FAQ](https://docs.carto.com/faqs/carto-basemaps) and
  [Basemap Terms](https://carto.com/legal/basemap-terms/). Since 25 September
  2026 the raster endpoints require a key.
- Tiles (fallback): `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, ©
  OpenStreetMap contributors. Only the nine tiles around the centre are
  requested; there is no prefetching or bulk download. Respect the
  [tile usage policy](https://operations.osmfoundation.org/policies/tiles/).
  In dark mode the fallback is dimmed so it still reads as a dark surface, and
  the status pill says it is the fallback.
- Search: Nominatim, up to five results. Requests are user-triggered and
  throttled to one every 1.1 seconds to match the
  [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/).
  Nominatim rejects Qt's stock User-Agent with HTTP 403, so the extension sets
  an identifying User-Agent header itself. No API key is used.
- Standard 256 px tiles are used (no HiDPI variants). There is no offline map
  pack: cached tiles render without a network, but an uncached tile shows the
  loading/error state and the retry affordance.

## Cache and states

- Tiles are cached under `$XDG_CACHE_HOME/caelestia/maps/` (by default
  `~/.cache/caelestia/maps/`):
  - `carto/light_all/<z>/<x>/<y>.png`
  - `carto/dark_all/<z>/<x>/<y>.png`
  - `osm/<z>/<x>/<y>.png` for the fallback
  The style is part of the key, so a light tile is never shown in dark mode and
  a fallback tile never masquerades as a CARTO tile. The API key is never part
  of a cache key or path.
- The map shows **Loading map…** until the first tile arrives, **Map tiles
  unavailable — check your connection** when every request fails, and a
  per-tile **Tile unavailable** message plus a **Retry** action for partial
  failures. A missing key is called out explicitly, and fallback use is never
  silent.
- Only the nine tiles of the visible 3x3 grid are requested, and only while the
  Maps tab is selected. Requests are staggered instead of fired as a burst; a
  cached tile is not refetched by pan, zoom or shell restart.

## OSM policy compliance for the fallback

- Tile requests identify the app:
  `Maria-Padilha-Maps/1.0 (+https://github.com/maria-padilha-os/maria-padilha-de)`.
- Only the nine visible tiles are requested; nothing is prefetched.
- A cached fallback tile is reused across pans, zooms and restarts.
- The "© OpenStreetMap contributors" credit is always visible and links to
  https://www.openstreetmap.org/copyright.
- Nominatim search sends the same identifying User-Agent, is user-triggered only,
  and is throttled to one request per 1.1 s.

## Tests

`tests/extensions/maps.test.js` exercises style selection, URL construction,
key encoding/absence and cache keys with no Qt or network access. It runs as
part of `bash tests/all.sh`.
