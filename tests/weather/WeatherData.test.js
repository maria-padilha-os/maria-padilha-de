#!/usr/bin/env node
// Pure unit tests for shell/services/WeatherData.js. Fixtures are checked into
// tests/weather/fixtures; no Qt, display, provider process or network is used.

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..", "..");
const Weather = require(path.join(root, "shell", "services", "WeatherData.js"));
const fixture = name => fs.readFileSync(path.join(__dirname, "fixtures", name), "utf8");

let passed = 0;

function test(name, fn) {
    try {
        fn();
    } catch (error) {
        console.error(`  FAIL ${name}`);
        console.error(`       ${error.message}`);
        process.exitCode = 1;
        return;
    }
    passed += 1;
    console.log(`  ok   ${name}`);
}

console.log("weather config");

test("the provider config lives in the Padilha config directory", () => {
    assert.equal(Weather.configPath("/home/person", ""), "/home/person/.config/padilha/weather.conf");
    assert.equal(Weather.configPath("/home/person", "/tmp/xdg"), "/tmp/xdg/padilha/weather.conf");
    assert.equal(Weather.configPath("", ""), "weather.conf");
});

test("the config parser accepts aliases, comments and quotes", () => {
    const parsed = Weather.parseConfig(
        "# weather provider\n"
        + "; the key stays outside the checkout\n"
        + "provider_url = \"https://weather.example.test/v1/forecast?tenant=1\"\n"
        + "api_key = 'sekret-key'\n"
        + "geocoding_url=https://places.example.test/search\n"
        + "language = pt-BR\n"
        + "refresh_interval = 900\n"
        + "cache_ttl = 7200\n"
        + "ignored = value\n",
    );
    assert.equal(parsed.providerUrl, "https://weather.example.test/v1/forecast?tenant=1");
    assert.equal(parsed.apiKey, "sekret-key");
    assert.equal(parsed.geocodingUrl, "https://places.example.test/search");
    assert.equal(parsed.language, "pt-BR");
    assert.equal(parsed.refreshInterval, "900");
    assert.equal(parsed.cacheTtl, "7200");
    assert.equal(Weather.parseConfig("").apiKey, "");
    assert.equal(Weather.parseConfig("api_key =   ").apiKey, "");
});

console.log("provider URLs");

test("the default forecast URL carries coordinates and the fixture query", () => {
    const url = Weather.buildWeatherUrl({ latitude: -30.0346, longitude: -51.2177 });
    assert.match(url, /^https:\/\/api\.open-meteo\.com\/v1\/forecast\?/);
    assert.match(url, /latitude=-30\.0346/);
    assert.match(url, /longitude=-51\.2177/);
    assert.match(url, /timezone=auto/);
    assert.match(url, /forecast_days=7/);
});

test("a custom provider keeps its own query and receives the key", () => {
    const url = Weather.buildWeatherUrl({
        providerUrl: "https://weather.example.test/v1/forecast?tenant=home",
        apiKey: "abc 123&x=y",
        latitude: 12.5,
        longitude: -7.25,
    });
    assert.match(url, /^https:\/\/weather\.example\.test\/v1\/forecast\?tenant=home&/);
    assert.match(url, /apikey=abc%20123%26x%3Dy/);
    assert.match(url, /latitude=12\.5/);
    assert.match(url, /longitude=-7\.25/);
});

test("invalid provider URLs and coordinates are refused", () => {
    assert.equal(Weather.buildWeatherUrl({ providerUrl: "javascript:alert(1)", latitude: 0, longitude: 0 }), "");
    assert.equal(Weather.buildWeatherUrl({ providerUrl: "file:///tmp/weather", latitude: 0, longitude: 0 }), "");
    assert.equal(Weather.buildWeatherUrl({ latitude: 91, longitude: 0 }), "");
    assert.equal(Weather.buildWeatherUrl({ latitude: 0, longitude: 181 }), "");
    assert.equal(Weather.buildWeatherUrl({ latitude: "nope", longitude: 0 }), "");
});

test("the configured language is sent to the provider as well as to search", () => {
    const url = Weather.buildWeatherUrl({ latitude: 0, longitude: 0, language: "pt-BR" });
    assert.match(url, /lang=pt-BR/);
});

test("the geocoding URL is explicit and language-aware", () => {
    const url = Weather.buildGeocodingUrl({ query: "São Paulo", language: "pt-BR", count: 5 });
    assert.match(url, /^https:\/\/geocoding-api\.open-meteo\.com\/v1\/search\?/);
    assert.match(url, /name=S%C3%A3o%20Paulo/);
    assert.match(url, /language=pt-BR/);
    assert.match(url, /count=5/);
    assert.match(url, /format=json/);
    assert.equal(Weather.buildGeocodingUrl({ query: "   " }), "");
    assert.equal(Weather.buildGeocodingUrl({ query: "x", geocodingUrl: "ftp://example.test" }), "");
});

test("refresh and cache intervals are bounded", () => {
    assert.equal(Weather.refreshSeconds(""), Weather.DEFAULT_REFRESH_SECONDS);
    assert.equal(Weather.refreshSeconds(0), Weather.MIN_REFRESH_SECONDS);
    assert.equal(Weather.refreshSeconds(999999), Weather.MAX_REFRESH_SECONDS);
    assert.equal(Weather.cacheTtlSeconds(0), Weather.MIN_CACHE_TTL_SECONDS);
    assert.equal(Weather.cacheTtlSeconds(999999), Weather.MAX_CACHE_TTL_SECONDS);
});

console.log("forecast fixtures");

test("the fixture parses into current, daily and future-hourly data", () => {
    const parsed = Weather.parseWeatherResponse(fixture("forecast.json"), {
        now: new Date("2026-11-17T09:00:00").getTime(),
    });
    assert.equal(parsed.cc.weatherCode, 2);
    assert.equal(parsed.cc.tempC, 21.5);
    assert.equal(parsed.cc.feelsLikeC, 22.1);
    assert.equal(parsed.cc.humidity, 72);
    assert.equal(parsed.cc.windSpeed, 11.4);
    assert.equal(parsed.cc.sunrise, "2026-11-17 06:12");
    assert.equal(parsed.cc.sunset, "2026-11-17 19:04");
    assert.equal(parsed.forecast.length, 3);
    assert.equal(parsed.forecast[0].date, "2026/11/17");
    assert.equal(parsed.forecast[0].maxTempC, 25.2);
    assert.equal(parsed.forecast[0].minTempC, 16.8);
    assert.equal(parsed.forecast[1].weatherCode, 61);
    assert.equal(parsed.hourlyForecast.length, 3);
    assert.equal(parsed.hourlyForecast[0].timestamp, "2026-11-17T10:00");
    assert.equal(parsed.hourlyForecast[0].hour, 10);
    assert.equal(parsed.hourlyForecast[0].precipChance, 10);
    assert.equal(parsed.hourlyForecast[1].tempC, 23.1);
});

test("hourly data is optional instead of fatal", () => {
    const parsed = Weather.parseWeatherResponse(fixture("forecast-no-hourly.json"), {
        now: new Date("2026-11-17T09:00:00").getTime(),
    });
    assert.equal(parsed.forecast.length, 1);
    assert.deepEqual(parsed.hourlyForecast, []);
});

test("an unusable provider response is rejected", () => {
    assert.throws(() => Weather.parseWeatherResponse(fixture("forecast-invalid.json")), /current|daily|weather code/);
    assert.throws(() => Weather.parseWeatherResponse("not json"), /JSON|Unexpected/);
    assert.throws(() => Weather.parseWeatherResponse(null), /empty/);
});

console.log("place fixtures");

test("place search results carry labels and drop invalid coordinates", () => {
    const results = Weather.parseGeocodingResponse(fixture("geocoding.json"));
    assert.equal(results.length, 2);
    assert.equal(results[0].name, "Porto Alegre");
    assert.equal(results[0].countryCode, "BR");
    assert.equal(results[0].label, "Porto Alegre, Brazil");
    assert.equal(results[0].displayName, "Porto Alegre, Rio Grande do Sul, Brazil");
    assert.equal(results[1].name, "São Paulo");
    assert.equal(results[1].countryCode, "BR");
    assert.equal(results[1].latitude, -23.5475);
    assert.equal(Weather.parseGeocodingResponse("{}").length, 0);
    assert.equal(Weather.parseGeocodingResponse("{\"results\":[]}").length, 0);
});

console.log("saved coordinates");

test("a saved location can be coordinates or a place name", () => {
    const coords = Weather.coordinatesOf(" -30.0346, -51.2177 ");
    assert.equal(coords.latitude, -30.0346);
    assert.equal(coords.longitude, -51.2177);
    assert.equal(Weather.coordinatesOf("Porto Alegre, Brazil"), null);
    assert.equal(Weather.coordinatesOf("91, 0"), null);
    assert.equal(Weather.coordinatesOf("-30.0346, -181"), null);
    assert.equal(Weather.formatCoordinates(coords), "-30.0346,-51.2177");
});

test("location keys are stable across case and whitespace", () => {
    assert.equal(Weather.locationKey(" Porto   Alegre "), Weather.locationKey("porto alegre"));
    assert.equal(Weather.locationKey("", { latitude: 1.5, longitude: 2.5 }), "coords:1.5,2.5");
    assert.equal(Weather.locationKey(""), "");
});

console.log("response cache");

test("a cache record never contains the provider key", () => {
    const record = Weather.makeCacheRecord(JSON.parse(fixture("forecast.json")), {
        location: "Porto Alegre, Brazil",
        coordinates: "-30.0346,-51.2177",
        city: "Porto Alegre",
        countryCode: "BR",
        providerUrl: "https://weather.example.test/v1/forecast?apikey=sekret",
        updatedAt: 1000000,
    });
    const serialized = JSON.stringify(record);
    assert.ok(!serialized.includes("sekret"));
    assert.equal(record.provider, "https://weather.example.test");
    assert.equal(record.coordinates, "-30.0346,-51.2177");
    assert.equal(record.city, "Porto Alegre");
});

test("cache keys use the provider origin, never the query", () => {
    const key = Weather.cacheKey({
        providerUrl: "https://weather.example.test/v1/forecast?apikey=sekret",
        location: "Porto Alegre, Brazil",
        coordinates: "-30.0346,-51.2177",
    });
    assert.equal(key, "https://weather.example.test|coords:-30.0346,-51.2177");
    assert.ok(!key.includes("sekret"));
});

test("a cache record matches only the same provider and location", () => {
    const record = Weather.makeCacheRecord(JSON.parse(fixture("forecast.json")), {
        location: "Porto Alegre, Brazil",
        coordinates: "-30.0346,-51.2177",
        providerUrl: "https://api.open-meteo.com/v1/forecast",
        updatedAt: 1000000,
    });
    assert.equal(Weather.cacheMatches(record, {
        providerUrl: "https://api.open-meteo.com/v1/forecast",
        location: "Porto Alegre, Brazil",
        coordinates: "-30.0346,-51.2177",
    }), true);
    assert.equal(Weather.cacheMatches(record, {
        providerUrl: "https://other.example.test/v1/forecast",
        location: "Porto Alegre, Brazil",
        coordinates: "-30.0346,-51.2177",
    }), false);
    assert.equal(Weather.cacheMatches(record, {
        providerUrl: "https://api.open-meteo.com/v1/forecast",
        location: "Porto Alegre, Brazil",
        coordinates: "-23.5475,-46.6361",
    }), false);
    assert.equal(Weather.cacheMatches(record, {
        providerUrl: "https://api.open-meteo.com/v1/forecast",
        location: "São Paulo, Brazil",
    }), false);
});

test("cache reads reject malformed and old-format records", () => {
    const record = Weather.makeCacheRecord({}, { location: "x", updatedAt: 1000000 });
    assert.ok(Weather.readCache(JSON.stringify(record)));
    assert.equal(Weather.readCache("not json"), null);
    assert.equal(Weather.readCache("{}"), null);
    assert.equal(Weather.readCache(JSON.stringify(Object.assign({}, record, { version: 0 }))), null);
    assert.equal(Weather.readCache(JSON.stringify(Object.assign({}, record, { updatedAt: 0 }))), null);
    assert.equal(Weather.readCache(JSON.stringify(Object.assign({}, record, { payload: null }))), null);
});

test("freshness respects the exact bounded TTL", () => {
    const record = Weather.makeCacheRecord({}, { location: "x", updatedAt: 1000000 });
    assert.equal(Weather.cacheAgeMs(record, 1000000 + 300000), 300000);
    assert.equal(Weather.isCacheFresh(record, 300, 1000000 + 300000), true);
    assert.equal(Weather.isCacheFresh(record, 300, 1000000 + 300001), false);
    assert.equal(Weather.isCacheFresh(record, 300, 1000000 - 1), false);
    assert.equal(Weather.isCacheFresh(record, 0, 1000000 + 300000), true);
    assert.equal(Weather.isCacheFresh(record, 999999, 1000000 + 86400000), true);
});

if (process.exitCode) {
    console.error(`\n${passed} weather checks passed, with failures`);
} else {
    console.log(`\n${passed} weather checks passed`);
}
