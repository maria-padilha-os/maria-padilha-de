#!/usr/bin/env node
// Pure unit tests for the MPRIS metadata and transport helpers. The objects
// below are the same shape as a Quickshell MprisPlayer, but they are plain
// JavaScript: no D-Bus, no player process and no audio in CI.

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const Media = require(path.join(__dirname, "..", "..", "shell", "services", "MediaInfo.js"));

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

function fakePlayer(overrides) {
    return Object.assign({
        trackTitle: "Fake Track",
        trackArtist: "Fake Artist",
        trackAlbum: "Fake Album",
        trackArtUrl: "file:///tmp/fake-cover.png",
        metadata: {},
        length: 180,
        position: 42,
        canSeek: true,
        positionSupported: true,
        canControl: true,
        volume: 0.6,
        volumeSupported: true,
        isPlaying: false,
    }, overrides || {});
}

console.log("track metadata");

test("track fields use the player and a stable fallback", () => {
    const player = fakePlayer();
    assert.equal(Media.trackTitle(player), "Fake Track");
    assert.equal(Media.trackArtist(player), "Fake Artist");
    assert.equal(Media.trackAlbum(player), "Fake Album");
    assert.equal(Media.trackTitle(player, "Unknown"), "Fake Track");
    assert.equal(Media.trackTitle(fakePlayer({ trackTitle: "   " }), "Unknown"), "Unknown");
    assert.equal(Media.trackTitle(null, "Unknown"), "Unknown");
    assert.equal(Media.metadataValue(player, "xesam:url"), "");
});

test("unknown values never become the string null or undefined", () => {
    assert.equal(Media.trackTitle({}, "Unknown"), "Unknown");
    assert.equal(Media.trackArtist({ trackArtist: null }, "Unknown"), "Unknown");
    assert.equal(Media.trackAlbum({ trackAlbum: undefined }, "Unknown"), "Unknown");
});

console.log("artwork URLs");

test("the player's image URL wins when it is an allowed image scheme", () => {
    assert.equal(Media.artUrl(fakePlayer()), "file:///tmp/fake-cover.png");
    assert.equal(Media.artUrl(fakePlayer({ trackArtUrl: "https://example.test/a.png" })), "https://example.test/a.png");
    assert.equal(Media.artUrl(fakePlayer({ trackArtUrl: "data:image/png;base64,AAAA" })), "data:image/png;base64,AAAA");
});

test("a bare absolute path becomes a file URL", () => {
    assert.equal(Media.artUrl(fakePlayer({ trackArtUrl: "/tmp/cover.jpg" })), "file:///tmp/cover.jpg");
});

test("unsafe or malformed artwork URLs fall back to the placeholder", () => {
    for (const value of ["", "   ", "javascript:alert(1)", "smb://host/cover.png", "cover.png", "~/.cover.png"]) {
        assert.equal(Media.artUrl(fakePlayer({ trackArtUrl: value })), "", value);
    }
});

test("a YouTube track URL only supplies a thumbnail when it has an id", () => {
    const withId = fakePlayer({
        trackArtUrl: "",
        metadata: { "xesam:url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ" },
    });
    assert.equal(Media.artUrl(withId), "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg");

    const withoutId = fakePlayer({
        trackArtUrl: "",
        metadata: { "xesam:url": "https://www.youtube.com/watch" },
    });
    assert.equal(Media.artUrl(withoutId), "");
});

test("artwork from a missing player is empty", () => {
    assert.equal(Media.artUrl(null), "");
});

console.log("seek state");

test("length is known only for finite, positive, non-huge values", () => {
    assert.equal(Media.isKnownLength(fakePlayer()), true);
    assert.equal(Media.isKnownLength(fakePlayer({ length: 0 })), false);
    assert.equal(Media.isKnownLength(fakePlayer({ length: -1 })), false);
    assert.equal(Media.isKnownLength(fakePlayer({ length: Infinity })), false);
    assert.equal(Media.isKnownLength(fakePlayer({ length: 2147483648 })), false);
    assert.equal(Media.isKnownLength(null), false);
});

test("seek is available only with capability and a known length", () => {
    assert.equal(Media.canSeek(fakePlayer()), true);
    assert.equal(Media.canSeek(fakePlayer({ canSeek: false })), false);
    assert.equal(Media.canSeek(fakePlayer({ positionSupported: false })), false);
    assert.equal(Media.canSeek(fakePlayer({ length: 0 })), false);
});

test("progress and seek targets are clamped to the track", () => {
    assert.equal(Media.progress(fakePlayer({ position: 90 })), 0.5);
    assert.equal(Media.progress(fakePlayer({ position: -1 })), 0);
    assert.equal(Media.progress(fakePlayer({ position: 500 })), 1);
    assert.equal(Media.seekTarget(fakePlayer(), 0.25), 45);
    assert.equal(Media.seekTarget(fakePlayer(), -1), 0);
    assert.equal(Media.seekTarget(fakePlayer(), 2), 180);
    assert.equal(Media.seekTarget(fakePlayer({ canSeek: false }), 0.5), -1);
});

test("seekTo and seekBy write only when the player can seek", () => {
    const player = fakePlayer();
    assert.equal(Media.seekTo(player, 50), true);
    assert.equal(player.position, 50);
    assert.equal(Media.seekBy(player, -10), true);
    assert.equal(player.position, 40);
    assert.equal(Media.seekBy(player, 500), true);
    assert.equal(player.position, 180);

    const locked = fakePlayer({ canSeek: false, position: 42 });
    assert.equal(Media.seekTo(locked, 10), false);
    assert.equal(locked.position, 42);
    assert.equal(Media.seekBy(locked, 10), false);
    assert.equal(locked.position, 42);
});

console.log("volume state");

test("volume is clamped and percent rounds", () => {
    assert.equal(Media.volume(fakePlayer({ volume: 0.6 })), 0.6);
    assert.equal(Media.volume(fakePlayer({ volume: -2 })), 0);
    assert.equal(Media.volume(fakePlayer({ volume: 4 })), 1);
    assert.equal(Media.volume(fakePlayer({ volume: NaN })), 0);
    assert.equal(Media.volumePercent(fakePlayer({ volume: 0.555 })), 56);
});

test("volume is written only when the player supports it", () => {
    const player = fakePlayer({ volume: 0.6 });
    assert.equal(Media.canSetVolume(player), true);
    assert.equal(Media.setVolume(player, 0.25), true);
    assert.equal(player.volume, 0.25);
    assert.equal(Media.changeVolume(player, 0.5), true);
    assert.equal(player.volume, 0.75);
    assert.equal(Media.changeVolume(player, 1), true);
    assert.equal(player.volume, 1);

    const locked = fakePlayer({ volumeSupported: false, volume: 0.6 });
    assert.equal(Media.canSetVolume(locked), false);
    assert.equal(Media.setVolume(locked, 0.1), false);
    assert.equal(locked.volume, 0.6);

    const uncontrolled = fakePlayer({ canControl: false, volume: 0.6 });
    assert.equal(Media.canSetVolume(uncontrolled), false);
    assert.equal(Media.setVolume(uncontrolled, 0.1), false);
    assert.equal(uncontrolled.volume, 0.6);
});

console.log("time and keyboard");

test("time labels handle minutes, hours and unknown values", () => {
    assert.equal(Media.formatTime(0), "0:00");
    assert.equal(Media.formatTime(65), "1:05");
    assert.equal(Media.formatTime(3661), "1:01:01");
    assert.equal(Media.formatTime(-1), "--:--");
    assert.equal(Media.formatTime(Infinity), "--:--");
    assert.equal(Media.formatTime(NaN), "--:--");
    assert.equal(Media.formatTime(undefined), "--:--");
});

test("Space, J/K/L and arrows map to native transport actions", () => {
    assert.equal(Media.actionForKey(32, false, true, true), "toggle");
    assert.equal(Media.actionForKey(75, false, true, true), "toggle");
    assert.equal(Media.actionForKey(74, false, true, true), "seekBackward");
    assert.equal(Media.actionForKey(76, false, true, true), "seekForward");
    assert.equal(Media.actionForKey(16777234, false, true, true), "seekBackward");
    assert.equal(Media.actionForKey(16777236, false, true, true), "seekForward");
    assert.equal(Media.actionForKey(16777234, true, true, true), "previous");
    assert.equal(Media.actionForKey(16777236, true, true, true), "next");
    assert.equal(Media.actionForKey(16777235, false, true, true), "volumeUp");
    assert.equal(Media.actionForKey(16777237, false, true, true), "volumeDown");
    assert.equal(Media.actionForKey(16777232, false, true, true), "seekStart");
    assert.equal(Media.actionForKey(16777233, false, true, true), "seekEnd");
    assert.equal(Media.actionForKey(77, false, true, true), "mute");
});

test("unavailable transport capabilities report no action", () => {
    assert.equal(Media.actionForKey(74, false, false, true), "none");
    assert.equal(Media.actionForKey(16777234, false, false, true), "none");
    assert.equal(Media.actionForKey(16777235, false, true, false), "none");
    assert.equal(Media.actionForKey(77, false, true, false), "none");
    assert.equal(Media.actionForKey(65, false, true, true), "none");
});

if (process.exitCode) {
    console.error(`\n${passed} media checks passed, with failures`);
} else {
    console.log(`\n${passed} media checks passed`);
}
