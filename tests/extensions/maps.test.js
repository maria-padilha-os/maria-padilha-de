#!/usr/bin/env node
// Pure unit tests for extensions/maps/MapStyle.js. No Qt, no tiles, no network.

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const MapStyle = require(path.join(__dirname, "..", "..", "extensions", "maps", "MapStyle.js"));

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

console.log("maps style selection");

test("dark mode selects the dark CARTO style", () => {
    assert.equal(MapStyle.styleForMode(true), "dark_all");
    assert.equal(MapStyle.styleForMode("dark"), "dark_all");
});

test("light mode selects the light CARTO style", () => {
    assert.equal(MapStyle.styleForMode(false), "light_all");
    assert.equal(MapStyle.styleForMode("light"), "light_all");
    assert.equal(MapStyle.styleForMode(undefined), "light_all");
});

test("an explicit Colours light flag wins over the surface", () => {
    assert.equal(MapStyle.isDarkMode({ light: true }, "#000000"), false);
    assert.equal(MapStyle.isDarkMode({ light: false }, "#ffffff"), true);
    assert.equal(MapStyle.styleForColours({ light: true }, "#000000"), "light_all");
    assert.equal(MapStyle.styleForColours({ light: false }, "#ffffff"), "dark_all");
});

test("surface luminance is the fallback when Colours is unavailable", () => {
    assert.equal(MapStyle.isDarkMode(null, "#ffffff"), false);
    assert.equal(MapStyle.isDarkMode(null, "#f8f8f8"), false);
    assert.equal(MapStyle.isDarkMode(null, "#000000"), true);
    assert.equal(MapStyle.isDarkMode(null, "#191114"), true);
    assert.equal(MapStyle.isDarkMode(null, "#fff"), false);
    assert.equal(MapStyle.isDarkMode(null, undefined), false);
});

console.log("maps tile URLs");

test("light and dark tiles use different CARTO URLs", () => {
    const light = MapStyle.cartoTileUrl("light_all", 12, 1485, 2244);
    const dark = MapStyle.cartoTileUrl("dark_all", 12, 1485, 2244);
    assert.equal(light, "https://basemaps.cartocdn.com/rastertiles/light_all/12/1485/2244.png");
    assert.equal(dark, "https://basemaps.cartocdn.com/rastertiles/dark_all/12/1485/2244.png");
    assert.notEqual(light, dark);
});

test("the configured key is appended and URL-encoded", () => {
    assert.equal(
        MapStyle.cartoTileUrl("dark_all", 3, 2, 1, "abc 123&x=y"),
        "https://basemaps.cartocdn.com/rastertiles/dark_all/3/2/1.png?key=abc%20123%26x%3Dy",
    );
});

test("an absent or whitespace-only key leaves the URL keyless", () => {
    const expected = "https://basemaps.cartocdn.com/rastertiles/light_all/3/2/1.png";
    assert.equal(MapStyle.cartoTileUrl("light_all", 3, 2, 1), expected);
    assert.equal(MapStyle.cartoTileUrl("light_all", 3, 2, 1, ""), expected);
    assert.equal(MapStyle.cartoTileUrl("light_all", 3, 2, 1, "   "), expected);
});

test("an unknown style is refused instead of building a URL", () => {
    assert.equal(MapStyle.cartoTileUrl("voyager", 3, 2, 1), "");
    assert.equal(MapStyle.cartoTileUrl("light", 3, 2, 1), "");
});

test("invalid tile coordinates are refused", () => {
    assert.equal(MapStyle.cartoTileUrl("light_all", "nope", 2, 1), "");
    assert.equal(MapStyle.osmTileUrl(-1, 2, 1), "");
    assert.equal(MapStyle.tileCacheKey("carto", "light_all", 3, -1, 1), "");
});

test("the OpenStreetMap fallback URL is independent of the style", () => {
    assert.equal(
        MapStyle.osmTileUrl(12, 1485, 2244),
        "https://tile.openstreetmap.org/12/1485/2244.png",
    );
    assert.equal(MapStyle.tileUrl("osm", "dark_all", 12, 1485, 2244), MapStyle.osmTileUrl(12, 1485, 2244));
});

console.log("maps cache keys");

test("the style is part of the cache key", () => {
    assert.equal(MapStyle.tileCacheKey("carto", "light_all", 12, 1485, 2244), "carto/light_all/12/1485/2244.png");
    assert.equal(MapStyle.tileCacheKey("carto", "dark_all", 12, 1485, 2244), "carto/dark_all/12/1485/2244.png");
    assert.notEqual(
        MapStyle.tileCacheKey("carto", "light_all", 12, 1485, 2244),
        MapStyle.tileCacheKey("carto", "dark_all", 12, 1485, 2244),
    );
});

test("the fallback has its own cache namespace", () => {
    assert.equal(MapStyle.tileCacheKey("osm", "dark_all", 12, 1485, 2244), "osm/12/1485/2244.png");
    assert.notEqual(
        MapStyle.tileCacheKey("osm", "dark_all", 12, 1485, 2244),
        MapStyle.tileCacheKey("carto", "dark_all", 12, 1485, 2244),
    );
});

test("cache paths keep zoom, x and y and never contain the key", () => {
    const cacheDir = "/home/person/.cache/caelestia/maps/";
    const light = MapStyle.tileCachePath(cacheDir, "carto", "light_all", 12, 1485, 2244);
    const dark = MapStyle.tileCachePath(cacheDir, "carto", "dark_all", 12, 1485, 2244);
    assert.equal(light, "/home/person/.cache/caelestia/maps/carto/light_all/12/1485/2244.png");
    assert.equal(dark, "/home/person/.cache/caelestia/maps/carto/dark_all/12/1485/2244.png");
    assert.ok(!light.includes("secret-key"));
    assert.ok(!dark.includes("key="));
});

console.log("maps config");

test("the key config lives beside the other Padilha config", () => {
    assert.equal(MapStyle.configPath("/home/person", ""), "/home/person/.config/padilha/maps.conf");
    assert.equal(MapStyle.configPath("/home/person", "/tmp/xdg"), "/tmp/xdg/padilha/maps.conf");
    assert.equal(MapStyle.configPath("", ""), "maps.conf");
});

test("the config parser accepts comments, whitespace and quotes", () => {
    const parsed = MapStyle.parseConfig(
        "# a comment\n"
        + "; another\n"
        + "carto_key = \"abc123\"\n"
        + "ignored = value\n",
    );
    assert.equal(parsed.cartoKey, "abc123");
    assert.equal(MapStyle.parseConfig("api_key='xyz'").cartoKey, "xyz");
    assert.equal(MapStyle.parseConfig("key = bare").cartoKey, "bare");
    assert.equal(MapStyle.parseConfig("").cartoKey, "");
    assert.equal(MapStyle.parseConfig("carto_key =   ").cartoKey, "");
});

test("keys are trimmed and surrounding quotes removed", () => {
    assert.equal(MapStyle.normaliseKey("  \"abc\"  "), "abc");
    assert.equal(MapStyle.normaliseKey("'abc'"), "abc");
    assert.equal(MapStyle.normaliseKey(null), "");
});

test("attribution names the data and the provider", () => {
    assert.match(MapStyle.OSM_ATTRIBUTION, /OpenStreetMap/);
    assert.match(MapStyle.CARTO_ATTRIBUTION, /CARTO/);
    assert.match(MapStyle.CARTO_KEY_URL, /carto\.com\/basemaps\/apikey/);
    assert.match(MapStyle.CARTO_ATTRIBUTION_URL, /carto\.com\/attribution/);
});

if (process.exitCode) {
    console.error(`\n${passed} maps checks passed, with failures`);
} else {
    console.log(`\n${passed} maps checks passed`);
}
