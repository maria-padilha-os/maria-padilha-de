// Pure weather helpers: provider/config URLs, response parsing and the bounded
// response cache. Keeping this out of Weather.qml lets the contract tests run
// against fixture responses without Qt, a display, or the network.
//
// The default provider is Open-Meteo, which needs no key. A private or
// self-hosted Open-Meteo-compatible endpoint can be supplied at runtime:
//
//   # ~/.config/padilha/weather.conf
//   provider_url = https://weather.example.test/v1/forecast
//   api_key = YOUR_KEY
//
// The file lives outside this checkout and is never written by the shell.
// PADILHA_WEATHER_PROVIDER_URL / PADILHA_WEATHER_API_KEY win over the file.

var DEFAULT_PROVIDER_URL = "https://api.open-meteo.com/v1/forecast";
var DEFAULT_GEOCODING_URL = "https://geocoding-api.open-meteo.com/v1/search";

var DEFAULT_REFRESH_SECONDS = 1800; // 30 minutes
var DEFAULT_CACHE_TTL_SECONDS = 3600; // 1 hour
var MIN_REFRESH_SECONDS = 300; // never poll more than once every 5 minutes
var MAX_REFRESH_SECONDS = 21600; // six hours
var MIN_CACHE_TTL_SECONDS = 300;
var MAX_CACHE_TTL_SECONDS = 86400; // one day

var CACHE_VERSION = 1;
var MAX_GEOCODING_RESULTS = 5;

var WEATHER_PARAMS = {
    "hourly": "weather_code,temperature_2m,precipitation_probability",
    "daily": "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset",
    "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m",
    "timezone": "auto",
    "forecast_days": "7"
};

function normaliseString(value) {
    if (value === undefined || value === null)
        return "";
    return String(value).trim();
}

function normaliseKey(value) {
    return normaliseString(value).replace(/^["']|["']$/g, "").trim();
}

function isHttpUrl(value) {
    return /^https?:\/\/[^\s]+$/i.test(normaliseString(value));
}

function numberOrNull(value) {
    var number = Number(value);
    return isFinite(number) ? number : null;
}

function numberInRange(value, min, max) {
    var number = Number(value);
    if (!isFinite(number) || number < min || number > max)
        return null;
    return number;
}

function clampInteger(value, fallback, min, max) {
    var number = Number(value);
    if (!isFinite(number) || String(value).trim() === "")
        number = Number(fallback);
    if (!isFinite(number))
        return fallback;
    number = Math.round(number);
    return Math.max(min, Math.min(max, number));
}

function refreshSeconds(value) {
    return clampInteger(value, DEFAULT_REFRESH_SECONDS, MIN_REFRESH_SECONDS, MAX_REFRESH_SECONDS);
}

function cacheTtlSeconds(value) {
    return clampInteger(value, DEFAULT_CACHE_TTL_SECONDS, MIN_CACHE_TTL_SECONDS, MAX_CACHE_TTL_SECONDS);
}

function configPath(home, xdgConfigHome) {
    var base = normaliseString(xdgConfigHome);
    if (!base)
        base = home ? normaliseString(home).replace(/\/+$/, "") + "/.config" : "";
    if (!base)
        return "weather.conf";
    return base.replace(/\/+$/, "") + "/padilha/weather.conf";
}

// Parse the optional user config file. Unknown keys and comments are ignored.
// Values are intentionally not written back: the key must stay out of the
// shell's generated JSON and out of this checkout.
function parseConfig(text) {
    var result = {
        "providerUrl": "",
        "apiKey": "",
        "geocodingUrl": "",
        "language": "",
        "refreshInterval": "",
        "cacheTtl": ""
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

        if (name === "provider_url" || name === "provider" || name === "url")
            result.providerUrl = value;
        else if (name === "api_key" || name === "key" || name === "apikey")
            result.apiKey = value;
        else if (name === "geocoding_url" || name === "geocoding" || name === "search_url")
            result.geocodingUrl = value;
        else if (name === "language" || name === "lang")
            result.language = value;
        else if (name === "refresh_interval" || name === "refresh")
            result.refreshInterval = value;
        else if (name === "cache_ttl" || name === "cache_ttl_seconds" || name === "ttl")
            result.cacheTtl = value;
    }
    return result;
}

function hasQueryParam(url, name) {
    return new RegExp("[?&]" + name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "=", "i").test(url);
}

function appendParams(url, params) {
    var query = [];
    for (var key in params) {
        if (!Object.prototype.hasOwnProperty.call(params, key))
            continue;
        var value = params[key];
        if (value === undefined || value === null || value === "")
            continue;
        if (hasQueryParam(url, key))
            continue;
        query.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(value)));
    }
    if (query.length === 0)
        return url;
    var separator = url.indexOf("?") === -1 ? "?" : (url.charAt(url.length - 1) === "?" || url.charAt(url.length - 1) === "&" ? "" : "&");
    return url + separator + query.join("&");
}

function coordinatePair(latitude, longitude) {
    var lat = numberInRange(latitude, -90, 90);
    var lon = numberInRange(longitude, -180, 180);
    if (lat === null || lon === null)
        return null;
    return { "latitude": lat, "longitude": lon };
}

// Accepts a saved "lat,lon" string from the config or a search result.
function coordinatesOf(value) {
    if (value && typeof value === "object" && value.latitude !== undefined)
        return coordinatePair(value.latitude, value.longitude);

    var text = normaliseString(value);
    var match = /^\s*(-?(?:\d+(?:\.\d+)?|\.\d+))\s*,\s*(-?(?:\d+(?:\.\d+)?|\.\d+))\s*$/.exec(text);
    if (!match)
        return null;
    return coordinatePair(match[1], match[2]);
}

function formatCoordinates(coords) {
    if (!coords)
        return "";
    var lat = Number(coords.latitude);
    var lon = Number(coords.longitude);
    if (!isFinite(lat) || !isFinite(lon))
        return "";
    return lat.toFixed(4).replace(/\.?0+$/, "") + "," + lon.toFixed(4).replace(/\.?0+$/, "");
}

function locationKey(location, coords) {
    var pair = coords ? coordinatesOf(coords) : null;
    if (pair)
        return "coords:" + formatCoordinates(pair);
    var text = normaliseString(location).replace(/\s+/g, " ").toLowerCase();
    return text.length > 0 ? "name:" + text : "";
}

// The provider origin is the cache namespace. Paths, queries and credentials
// are dropped so an API key embedded in a URL can never reach the cache.
function providerOrigin(value) {
    var url = normaliseString(value);
    var match = /^(https?):\/\/(?:[^@/?#]*@)?([^/?#:]+)(?::(\d+))?/i.exec(url);
    if (!match)
        return "";
    return match[1].toLowerCase() + "://" + match[2].toLowerCase() + (match[3] ? ":" + match[3] : "");
}

function cacheKey(options) {
    options = options || {};
    var origin = providerOrigin(options.providerUrl || DEFAULT_PROVIDER_URL);
    var key = locationKey(options.location, options.coordinates);
    return origin + "|" + key;
}

function buildWeatherUrl(options) {
    options = options || {};
    var base = normaliseString(options.providerUrl) || DEFAULT_PROVIDER_URL;
    if (!isHttpUrl(base))
        return "";

    var coords = coordinatePair(options.latitude, options.longitude);
    if (!coords)
        return "";

    var params = {};
    for (var key in WEATHER_PARAMS)
        params[key] = WEATHER_PARAMS[key];
    params.latitude = coords.latitude;
    params.longitude = coords.longitude;

    var apiKey = normaliseString(options.apiKey);
    if (apiKey.length > 0)
        params.apikey = apiKey;

    var language = normaliseString(options.language);
    if (language.length > 0)
        params.lang = language;

    return appendParams(base, params);
}

function buildGeocodingUrl(options) {
    options = options || {};
    var base = normaliseString(options.geocodingUrl) || DEFAULT_GEOCODING_URL;
    if (!isHttpUrl(base))
        return "";
    var query = normaliseString(options.query);
    if (query.length === 0)
        return "";

    var count = Number(options.count);
    if (!isFinite(count) || count < 1)
        count = MAX_GEOCODING_RESULTS;
    count = Math.min(MAX_GEOCODING_RESULTS, Math.round(count));

    var params = {
        "name": query,
        "count": count,
        "format": "json"
    };
    var language = normaliseString(options.language);
    if (language.length > 0)
        params.language = language;
    return appendParams(base, params);
}

function parseJson(input) {
    if (typeof input === "string")
        return JSON.parse(input);
    if (input && typeof input === "object")
        return input;
    throw new Error("empty response");
}

function valueAt(list, index) {
    return Array.isArray(list) && index < list.length ? list[index] : null;
}

function dateParts(value) {
    var text = normaliseString(value);
    if (text.length === 0)
        return null;
    var date = new Date(text.replace("T", " "));
    return isNaN(date.getTime()) ? null : date;
}

function parseWeatherResponse(input, options) {
    options = options || {};
    var json = parseJson(input);
    if (!json || typeof json !== "object")
        throw new Error("weather response is not an object");
    if (!json.current || typeof json.current !== "object")
        throw new Error("weather response has no current conditions");
    if (!json.daily || !Array.isArray(json.daily.time) || json.daily.time.length === 0)
        throw new Error("weather response has no daily forecast");

    var current = json.current;
    var daily = json.daily;
    var weatherCode = numberOrNull(current.weather_code);
    if (weatherCode === null)
        throw new Error("weather response has no weather code");

    var sunrise = valueAt(daily.sunrise, 0);
    var sunset = valueAt(daily.sunset, 0);
    var cc = {
        "weatherCode": weatherCode,
        "tempC": numberOrNull(current.temperature_2m),
        "feelsLikeC": numberOrNull(current.apparent_temperature),
        "humidity": numberOrNull(current.relative_humidity_2m),
        "windSpeed": numberOrNull(current.wind_speed_10m),
        "isDay": numberOrNull(current.is_day),
        "sunrise": sunrise ? String(sunrise).replace("T", " ") : "",
        "sunset": sunset ? String(sunset).replace("T", " ") : ""
    };

    var forecast = [];
    for (var i = 0; i < daily.time.length; ++i) {
        var date = normaliseString(daily.time[i]);
        if (date.length === 0)
            continue;
        forecast.push({
            "date": date.replace(/-/g, "/"),
            "maxTempC": numberOrNull(valueAt(daily.temperature_2m_max, i)),
            "minTempC": numberOrNull(valueAt(daily.temperature_2m_min, i)),
            "weatherCode": numberOrNull(valueAt(daily.weather_code, i))
        });
    }
    if (forecast.length === 0)
        throw new Error("weather response has no usable forecast days");

    var hourly = [];
    if (json.hourly && Array.isArray(json.hourly.time)) {
        var now = options.now === undefined ? Date.now() : Number(options.now);
        if (!isFinite(now))
            now = Date.now();
        for (var j = 0; j < json.hourly.time.length; ++j) {
            var time = dateParts(json.hourly.time[j]);
            if (!time || time.getTime() < now)
                continue;
            hourly.push({
                "timestamp": String(json.hourly.time[j]),
                "hour": time.getHours(),
                "tempC": numberOrNull(valueAt(json.hourly.temperature_2m, j)),
                "precipChance": numberOrNull(valueAt(json.hourly.precipitation_probability, j)),
                "weatherCode": numberOrNull(valueAt(json.hourly.weather_code, j))
            });
        }
    }

    return {
        "cc": cc,
        "forecast": forecast,
        "hourlyForecast": hourly
    };
}

function joinUnique(parts) {
    var result = [];
    for (var i = 0; i < parts.length; ++i) {
        var part = normaliseString(parts[i]);
        if (part.length === 0)
            continue;
        if (result.some(function (value) { return value.toLowerCase() === part.toLowerCase(); }))
            continue;
        result.push(part);
    }
    return result;
}

function parseGeocodingResponse(input, options) {
    options = options || {};
    var json = parseJson(input);
    if (!json || !Array.isArray(json.results))
        return [];

    var limit = Number(options.count);
    if (!isFinite(limit) || limit < 1)
        limit = MAX_GEOCODING_RESULTS;
    limit = Math.min(MAX_GEOCODING_RESULTS, Math.round(limit));

    var results = [];
    for (var i = 0; i < json.results.length && results.length < limit; ++i) {
        var item = json.results[i];
        if (!item || typeof item !== "object")
            continue;
        var coords = coordinatePair(item.latitude, item.longitude);
        if (!coords)
            continue;
        var name = normaliseString(item.name) || normaliseString(item.admin1) || normaliseString(item.country);
        if (name.length === 0)
            continue;
        var countryCode = normaliseString(item.country_code).toUpperCase();
        var country = normaliseString(item.country);
        var admin1 = normaliseString(item.admin1);
        results.push({
            "name": name,
            "admin1": admin1,
            "country": country,
            "countryCode": countryCode,
            "latitude": coords.latitude,
            "longitude": coords.longitude,
            "displayName": joinUnique([name, admin1, country]).join(", "),
            "label": joinUnique([name, country]).join(", ")
        });
    }
    return results;
}

function makeCacheRecord(payload, options) {
    options = options || {};
    var coords = coordinatesOf(options.coordinates);
    var updatedAt = Number(options.updatedAt);
    if (!isFinite(updatedAt) || updatedAt <= 0)
        updatedAt = Date.now();
    return {
        "version": CACHE_VERSION,
        "location": normaliseString(options.location),
        "coordinates": coords ? formatCoordinates(coords) : "",
        "city": normaliseString(options.city),
        "countryCode": normaliseString(options.countryCode).toUpperCase(),
        "provider": providerOrigin(options.providerUrl || DEFAULT_PROVIDER_URL),
        "updatedAt": updatedAt,
        "payload": payload
    };
}

function readCache(input) {
    var record;
    try {
        record = parseJson(input);
    } catch (error) {
        return null;
    }
    if (!record || typeof record !== "object")
        return null;
    if (Number(record.version) !== CACHE_VERSION)
        return null;
    if (!record.payload || typeof record.payload !== "object")
        return null;
    var updatedAt = Number(record.updatedAt);
    if (!isFinite(updatedAt) || updatedAt <= 0)
        return null;
    return record;
}

function cacheMatches(record, options) {
    if (!record || !options)
        return false;

    var origin = providerOrigin(options.providerUrl || DEFAULT_PROVIDER_URL);
    if (origin.length > 0 && record.provider && origin !== record.provider)
        return false;

    var configuredCoords = coordinatesOf(options.coordinates);
    var storedCoords = coordinatesOf(record.coordinates);
    if (configuredCoords) {
        return !!storedCoords
            && Math.abs(configuredCoords.latitude - storedCoords.latitude) < 0.0001
            && Math.abs(configuredCoords.longitude - storedCoords.longitude) < 0.0001;
    }

    var key = locationKey(options.location, null);
    if (key.length === 0)
        return false;
    return key === locationKey(record.location, null);
}

function cacheAgeMs(record, now) {
    if (!record)
        return -1;
    var timestamp = Number(record.updatedAt);
    var current = now === undefined ? Date.now() : Number(now);
    if (!isFinite(timestamp) || !isFinite(current))
        return -1;
    return current - timestamp;
}

function isCacheFresh(record, ttlSeconds, now) {
    var age = cacheAgeMs(record, now);
    if (age < 0)
        return false;
    return age <= cacheTtlSeconds(ttlSeconds) * 1000;
}

// Node's test runner loads this module directly. QML's JS importer ignores the
// guard because its global scope has no CommonJS `module`.
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        DEFAULT_PROVIDER_URL: DEFAULT_PROVIDER_URL,
        DEFAULT_GEOCODING_URL: DEFAULT_GEOCODING_URL,
        DEFAULT_REFRESH_SECONDS: DEFAULT_REFRESH_SECONDS,
        DEFAULT_CACHE_TTL_SECONDS: DEFAULT_CACHE_TTL_SECONDS,
        MIN_REFRESH_SECONDS: MIN_REFRESH_SECONDS,
        MAX_REFRESH_SECONDS: MAX_REFRESH_SECONDS,
        MIN_CACHE_TTL_SECONDS: MIN_CACHE_TTL_SECONDS,
        MAX_CACHE_TTL_SECONDS: MAX_CACHE_TTL_SECONDS,
        CACHE_VERSION: CACHE_VERSION,
        MAX_GEOCODING_RESULTS: MAX_GEOCODING_RESULTS,
        normaliseString: normaliseString,
        normaliseKey: normaliseKey,
        isHttpUrl: isHttpUrl,
        refreshSeconds: refreshSeconds,
        cacheTtlSeconds: cacheTtlSeconds,
        configPath: configPath,
        parseConfig: parseConfig,
        appendParams: appendParams,
        coordinatesOf: coordinatesOf,
        formatCoordinates: formatCoordinates,
        locationKey: locationKey,
        providerOrigin: providerOrigin,
        cacheKey: cacheKey,
        buildWeatherUrl: buildWeatherUrl,
        buildGeocodingUrl: buildGeocodingUrl,
        parseWeatherResponse: parseWeatherResponse,
        parseGeocodingResponse: parseGeocodingResponse,
        makeCacheRecord: makeCacheRecord,
        readCache: readCache,
        cacheMatches: cacheMatches,
        cacheAgeMs: cacheAgeMs,
        isCacheFresh: isCacheFresh
    };
}
