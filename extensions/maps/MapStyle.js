// Pure style, tile-URL and cache-key helpers for the Maps extension.
//
// Keeping this logic in a plain JavaScript module lets the tests exercise it
// without Qt, a display, or the network. The QML widget imports it as
// `MapStyle`.
//
// Provider: CARTO raster basemaps. CARTO has required a free API key for the
// raster endpoints since 25 September 2026. The key is supplied by the user at
// runtime (PADILHA_MAPS_CARTO_KEY or ~/.config/padilha/maps.conf) and is never
// committed here. Without a key the widget deliberately uses the standard
// OpenStreetMap fallback instead of sending keyless CARTO requests.

var CARTO_PROVIDER = "carto";
var OSM_PROVIDER = "osm";

var LIGHT_STYLE = "light_all";
var DARK_STYLE = "dark_all";

var CARTO_RASTER_ROOT = "https://basemaps.cartocdn.com/rastertiles";
var OSM_TILE_ROOT = "https://tile.openstreetmap.org";

var OSM_ATTRIBUTION = "© OpenStreetMap contributors";
var CARTO_ATTRIBUTION = "© CARTO";
var OSM_COPYRIGHT_URL = "https://www.openstreetmap.org/copyright";
var CARTO_ATTRIBUTION_URL = "https://carto.com/attribution/";
var CARTO_KEY_URL = "https://carto.com/basemaps/apikey/";
var CARTO_TERMS_URL = "https://carto.com/legal/basemap-terms/";
var OSM_TILE_POLICY_URL = "https://operations.osmfoundation.org/policies/tiles/";

var MAX_ZOOM = 18;

// Accept a boolean or a mode name so callers cannot accidentally pass the
// wrong shape and end up with an unthemed map.
function styleForMode(mode) {
    if (mode === true || mode === "dark")
        return DARK_STYLE;
    return LIGHT_STYLE;
}

function isDarkColour(colour) {
    if (!colour)
        return false;

    var r;
    var g;
    var b;

    if (typeof colour === "string") {
        var hex = colour.trim().replace(/^#/, "");
        if (hex.length === 3) {
            r = parseInt(hex.charAt(0) + hex.charAt(0), 16);
            g = parseInt(hex.charAt(1) + hex.charAt(1), 16);
            b = parseInt(hex.charAt(2) + hex.charAt(2), 16);
        } else if (hex.length === 6 || hex.length === 8) {
            r = parseInt(hex.slice(0, 2), 16);
            g = parseInt(hex.slice(2, 4), 16);
            b = parseInt(hex.slice(4, 6), 16);
        } else {
            return false;
        }
        if (!isFinite(r) || !isFinite(g) || !isFinite(b))
            return false;
    } else if (typeof colour === "object" && colour.r !== undefined) {
        // QML `color` exposes channels as 0..1 reals.
        r = Number(colour.r) * 255;
        g = Number(colour.g) * 255;
        b = Number(colour.b) * 255;
    } else {
        return false;
    }

    return 0.299 * r + 0.587 * g + 0.114 * b < 128;
}

// The shell's Colours singleton has a reliable `light` flag. During the first
// frame (or in a test harness) it may be absent, so fall back to the surface
// luminance of whatever palette is available.
function modeForColours(colours, surface) {
    if (colours && typeof colours.light === "boolean")
        return colours.light ? "light" : "dark";
    return isDarkColour(surface) ? "dark" : "light";
}

function isDarkMode(colours, surface) {
    return modeForColours(colours, surface) === "dark";
}

function styleForColours(colours, surface) {
    return styleForMode(modeForColours(colours, surface));
}

function normaliseKey(key) {
    if (key === undefined || key === null)
        return "";
    return String(key).trim().replace(/^["']|["']$/g, "").trim();
}

function tileCoords(z, x, y) {
    var zoom = Number(z);
    var column = Number(x);
    var row = Number(y);
    if (!isFinite(zoom) || !isFinite(column) || !isFinite(row))
        return null;
    if (zoom < 0 || column < 0 || row < 0)
        return null;
    return {
        "z": zoom,
        "x": column,
        "y": row
    };
}

function cartoTileUrl(style, z, x, y, key) {
    if (style !== LIGHT_STYLE && style !== DARK_STYLE)
        return "";

    var coords = tileCoords(z, x, y);
    if (!coords)
        return "";

    var url = CARTO_RASTER_ROOT + "/" + style + "/" + coords.z + "/" + coords.x + "/" + coords.y + ".png";
    var cleanKey = normaliseKey(key);
    if (cleanKey.length > 0)
        url += "?key=" + encodeURIComponent(cleanKey);
    return url;
}

function osmTileUrl(z, x, y) {
    var coords = tileCoords(z, x, y);
    if (!coords)
        return "";
    return OSM_TILE_ROOT + "/" + coords.z + "/" + coords.x + "/" + coords.y + ".png";
}

function tileUrl(provider, style, z, x, y, key) {
    if (provider === OSM_PROVIDER)
        return osmTileUrl(z, x, y);
    return cartoTileUrl(style, z, x, y, key);
}

// The style is part of the key: light_all and dark_all must never share a
// cached PNG, and the fallback gets its own namespace so a CARTO cache entry
// cannot masquerade as an OpenStreetMap tile.
function tileCacheKey(provider, style, z, x, y) {
    var coords = tileCoords(z, x, y);
    if (!coords)
        return "";
    if (provider === OSM_PROVIDER)
        return "osm/" + coords.z + "/" + coords.x + "/" + coords.y + ".png";
    if (style !== LIGHT_STYLE && style !== DARK_STYLE)
        return "";
    return "carto/" + style + "/" + coords.z + "/" + coords.x + "/" + coords.y + ".png";
}

function tileCachePath(cacheDir, provider, style, z, x, y) {
    var key = tileCacheKey(provider, style, z, x, y);
    if (!key || !cacheDir)
        return "";
    return String(cacheDir).replace(/\/+$/, "") + "/" + key;
}

function configPath(home, xdgConfigHome) {
    var base = String(xdgConfigHome || "").trim();
    if (!base)
        base = home ? String(home).replace(/\/+$/, "") + "/.config" : "";
    if (!base)
        return "maps.conf";
    return base.replace(/\/+$/, "") + "/padilha/maps.conf";
}

// Parse the optional user config file. It is deliberately tiny:
//
//   # ~/.config/padilha/maps.conf
//   carto_key = YOUR_KEY
//
// Unknown keys and comments are ignored; env variables are read by the QML
// wrapper, not here.
function parseConfig(text) {
    var result = {
        "cartoKey": ""
    };
    if (!text)
        return result;

    var lines = String(text).replace(/^\uFEFF/, "").split(/\r?\n/);
    for (var i = 0; i < lines.length; ++i) {
        var line = lines[i].trim();
        if (line.length === 0 || line.charAt(0) === "#" || line.charAt(0) === ";")
            continue;
        var equals = line.indexOf("=");
        if (equals < 0)
            continue;
        var name = line.slice(0, equals).trim().toLowerCase();
        var value = normaliseKey(line.slice(equals + 1));
        if (name === "carto_key" || name === "carto_api_key" || name === "api_key" || name === "key")
            result.cartoKey = value;
    }
    return result;
}

// Node's test runner loads this module directly. QML's JS importer ignores the
// guard because its global scope has no CommonJS `module`.
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        CARTO_PROVIDER: CARTO_PROVIDER,
        OSM_PROVIDER: OSM_PROVIDER,
        LIGHT_STYLE: LIGHT_STYLE,
        DARK_STYLE: DARK_STYLE,
        OSM_ATTRIBUTION: OSM_ATTRIBUTION,
        CARTO_ATTRIBUTION: CARTO_ATTRIBUTION,
        OSM_COPYRIGHT_URL: OSM_COPYRIGHT_URL,
        CARTO_ATTRIBUTION_URL: CARTO_ATTRIBUTION_URL,
        CARTO_KEY_URL: CARTO_KEY_URL,
        CARTO_TERMS_URL: CARTO_TERMS_URL,
        OSM_TILE_POLICY_URL: OSM_TILE_POLICY_URL,
        MAX_ZOOM: MAX_ZOOM,
        styleForMode: styleForMode,
        isDarkColour: isDarkColour,
        modeForColours: modeForColours,
        isDarkMode: isDarkMode,
        styleForColours: styleForColours,
        normaliseKey: normaliseKey,
        cartoTileUrl: cartoTileUrl,
        osmTileUrl: osmTileUrl,
        tileUrl: tileUrl,
        tileCacheKey: tileCacheKey,
        tileCachePath: tileCachePath,
        configPath: configPath,
        parseConfig: parseConfig
    };
}
