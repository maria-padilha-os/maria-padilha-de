// Pure MPRIS metadata and transport helpers for the media widget.
//
// The file is imported by Players.qml, but deliberately keeps no dependency on
// Qt, D-Bus, timers or the active player. That lets the tests exercise it with
// plain fake MPRIS objects without starting a player or a display server.

var SEEK_STEP = 10;
var MAX_LENGTH = 2147483647;

var KEY_SPACE = 32;
var KEY_HOME = 16777232;
var KEY_END = 16777233;
var KEY_LEFT = 16777234;
var KEY_UP = 16777235;
var KEY_RIGHT = 16777236;
var KEY_DOWN = 16777237;
var KEY_J = 74;
var KEY_K = 75;
var KEY_L = 76;
var KEY_M = 77;

function text(value, fallback) {
    if (value === undefined || value === null)
        return fallback || "";
    var result = String(value).trim();
    return result.length > 0 ? result : (fallback || "");
}

function trackTitle(player, fallback) {
    return text(player && player.trackTitle, fallback);
}

function trackArtist(player, fallback) {
    return text(player && player.trackArtist, fallback);
}

function trackAlbum(player, fallback) {
    return text(player && player.trackAlbum, fallback);
}

function metadataValue(player, key) {
    if (!player || !player.metadata || typeof player.metadata !== "object")
        return "";
    return text(player.metadata[key], "");
}

// MPRIS art URLs are normally file:// or http(s) URLs, but players are free to
// publish anything. Only hand the image loader an image-shaped URL; schemes
// such as javascript: or smb: make the widget show its themed placeholder
// instead of trying (and failing) to load an arbitrary resource.
function normaliseArtUrl(value) {
    var raw = text(value, "");
    if (!raw)
        return "";

    var lower = raw.toLowerCase();
    if (lower.startsWith("data:image/"))
        return raw;

    var scheme = lower.match(/^[a-z][a-z0-9+.-]*:/);
    if (scheme) {
        if (scheme[0] === "file:" || scheme[0] === "http:" || scheme[0] === "https:")
            return raw;
        return "";
    }

    // Some players publish a bare absolute path even though the spec asks for
    // a URL. It is safe to turn that into a file URL.
    if (raw.charAt(0) === "/")
        return "file://" + raw;

    return "";
}

function artUrl(player) {
    if (!player)
        return "";

    var explicit = normaliseArtUrl(player.trackArtUrl);
    if (explicit)
        return explicit;

    var source = metadataValue(player, "xesam:url");
    if (source.startsWith("https://www.youtube.com/watch")) {
        var match = source.match(/[?&]v=([\w-]{11})/);
        if (match)
            return "https://img.youtube.com/vi/" + match[1] + "/hqdefault.jpg";
    }

    return "";
}

function isKnownLength(player) {
    if (!player)
        return false;
    var length = Number(player.length);
    return isFinite(length) && length > 0 && length <= MAX_LENGTH;
}

function isKnownPosition(player) {
    if (!player)
        return false;
    var position = Number(player.position);
    return position === position && isFinite(position) && position >= 0;
}

function canSeek(player) {
    return !!player && player.canSeek === true && player.positionSupported === true && isKnownLength(player);
}

function progress(player) {
    if (!player || !isKnownLength(player) || !isKnownPosition(player))
        return 0;
    return Math.max(0, Math.min(1, Number(player.position) / Number(player.length)));
}

function seekTarget(player, ratio) {
    if (!canSeek(player))
        return -1;
    var value = Number(ratio);
    if (value !== value || !isFinite(value))
        return -1;
    return Math.max(0, Math.min(Number(player.length), value * Number(player.length)));
}

function seekTo(player, position) {
    if (!canSeek(player))
        return false;
    var value = Number(position);
    if (value !== value || !isFinite(value))
        return false;
    player.position = Math.max(0, Math.min(Number(player.length), value));
    return true;
}

function seekBy(player, offset) {
    if (!canSeek(player))
        return false;
    var delta = Number(offset);
    if (delta !== delta || !isFinite(delta))
        return false;
    return seekTo(player, Number(player.position || 0) + delta);
}

function volume(player) {
    if (!player)
        return 0;
    var value = Number(player.volume);
    if (value !== value || !isFinite(value))
        return 0;
    return Math.max(0, Math.min(1, value));
}

function volumePercent(player) {
    return Math.round(volume(player) * 100);
}

function canSetVolume(player) {
    return !!player && player.volumeSupported === true && player.canControl === true;
}

function setVolume(player, value) {
    if (!canSetVolume(player))
        return false;
    var next = Number(value);
    if (next !== next || !isFinite(next))
        return false;
    player.volume = Math.max(0, Math.min(1, next));
    return true;
}

function changeVolume(player, delta) {
    var step = Number(delta);
    if (step !== step || !isFinite(step))
        return false;
    return setVolume(player, volume(player) + step);
}

function formatTime(value) {
    var seconds = Number(value);
    if (seconds !== seconds || !isFinite(seconds) || seconds < 0)
        return "--:--";

    seconds = Math.floor(seconds);
    var hours = Math.floor(seconds / 3600);
    var minutes = Math.floor((seconds % 3600) / 60);
    var rest = seconds % 60;
    var paddedRest = rest < 10 ? "0" + rest : String(rest);

    if (hours > 0) {
        var paddedMinutes = minutes < 10 ? "0" + minutes : String(minutes);
        return hours + ":" + paddedMinutes + ":" + paddedRest;
    }
    return minutes + ":" + paddedRest;
}

// Keyboard intent is kept here instead of in the popout so the mapping can be
// tested without a QML event object. `shift` is the only modifier the widget
// uses: Shift+Left/Right changes track, plain Left/Right seeks.
function actionForKey(key, shift, seekAvailable, volumeAvailable) {
    var code = Number(key);
    switch (code) {
    case KEY_SPACE:
    case KEY_K:
        return "toggle";
    case KEY_J:
        return seekAvailable ? "seekBackward" : "none";
    case KEY_L:
        return seekAvailable ? "seekForward" : "none";
    case KEY_LEFT:
        return shift ? "previous" : (seekAvailable ? "seekBackward" : "none");
    case KEY_RIGHT:
        return shift ? "next" : (seekAvailable ? "seekForward" : "none");
    case KEY_UP:
        return volumeAvailable ? "volumeUp" : "none";
    case KEY_DOWN:
        return volumeAvailable ? "volumeDown" : "none";
    case KEY_HOME:
        return seekAvailable ? "seekStart" : "none";
    case KEY_END:
        return seekAvailable ? "seekEnd" : "none";
    case KEY_M:
        return volumeAvailable ? "mute" : "none";
    default:
        return "none";
    }
}

// Node sees this as a CommonJS module. QML imports the same file as a script
// and never defines `module`, so the guard keeps both loaders happy.
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        SEEK_STEP: SEEK_STEP,
        MAX_LENGTH: MAX_LENGTH,
        text: text,
        trackTitle: trackTitle,
        trackArtist: trackArtist,
        trackAlbum: trackAlbum,
        metadataValue: metadataValue,
        normaliseArtUrl: normaliseArtUrl,
        artUrl: artUrl,
        isKnownLength: isKnownLength,
        isKnownPosition: isKnownPosition,
        canSeek: canSeek,
        progress: progress,
        seekTarget: seekTarget,
        seekTo: seekTo,
        seekBy: seekBy,
        volume: volume,
        volumePercent: volumePercent,
        canSetVolume: canSetVolume,
        setVolume: setVolume,
        changeVolume: changeVolume,
        formatTime: formatTime,
        actionForKey: actionForKey
    };
}
