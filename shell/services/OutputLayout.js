// Per-output panel layout metadata.
//
// The state file is deliberately boring: only connector identity, the output
// geometry needed to notice a rotation/scale change, and the anchor/offset of
// the shell's own panels.  It never contains a screenshot, wallpaper pixels,
// window titles, notification text, clipboard data or any other screen
// contents.  Unknown keys are dropped on load, so an older or hand-edited file
// cannot smuggle private data into the state we write back.

var VERSION = 1;
var MAX_OUTPUTS = 16;
var MAX_OFFSET = 4096;

var PANELS = ["bar", "launcher", "dashboard", "notifications", "wallpaper"];
var ANCHORS = [
    "top-left",
    "top-center",
    "top-right",
    "middle-left",
    "middle-center",
    "middle-right",
    "bottom-left",
    "bottom-center",
    "bottom-right",
    "fill"
];

var DEFAULTS = {
    bar: {
        edge: "right",
        offsetX: 0
    },
    launcher: {
        anchor: "bottom-center",
        offsetX: 0,
        offsetY: 0
    },
    dashboard: {
        anchor: "top-center",
        offsetX: 0,
        offsetY: 0
    },
    notifications: {
        anchor: "top-right",
        offsetX: 0,
        offsetY: 0
    },
    wallpaper: {
        anchor: "fill",
        offsetX: 0,
        offsetY: 0
    }
};

function cleanText(value, fallback, maxLength) {
    var result = value === undefined || value === null ? "" : String(value).trim();
    if (result.length === 0)
        result = fallback || "";
    if (result.length > (maxLength || 128))
        result = result.slice(0, maxLength || 128);
    return result;
}

function cleanKey(value) {
    var key = cleanText(value, "").replace(/[^0-9A-Za-z._-]/g, "_");
    if (key === "__proto__" || key === "constructor" || key === "prototype")
        return "";
    return key;
}

function finite(value, fallback) {
    var parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
}

function clamp(value, fallback) {
    var parsed = finite(value, fallback);
    return Math.max(-MAX_OFFSET, Math.min(MAX_OFFSET, Math.round(parsed)));
}

function positive(value, fallback) {
    var parsed = finite(value, fallback);
    return parsed > 0 ? Math.round(parsed) : fallback;
}

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

function defaultPosition(panel) {
    return clone(DEFAULTS[panel] || {});
}

function sanitisePosition(panel, raw) {
    var source = raw && typeof raw === "object" ? raw : {};
    var output = defaultPosition(panel);

    if (panel === "bar") {
        output.edge = source.edge === "left" ? "left" : "right";
        output.offsetX = clamp(source.offsetX, 0);
        return output;
    }

    output.anchor = ANCHORS.indexOf(source.anchor) >= 0 ? source.anchor : output.anchor;
    output.offsetX = clamp(source.offsetX, 0);
    output.offsetY = clamp(source.offsetY, 0);
    return output;
}

function sanitiseRecord(raw) {
    if (!raw || typeof raw !== "object")
        return null;

    var key = cleanKey(raw.key || raw.name);
    if (!key)
        return null;

    var record = {
        key: key,
        name: cleanText(raw.name, key),
        width: positive(raw.width, 0),
        height: positive(raw.height, 0),
        x: Math.round(finite(raw.x, 0)),
        y: Math.round(finite(raw.y, 0)),
        devicePixelRatio: Math.max(0.1, finite(raw.devicePixelRatio, 1)),
        orientation: Math.round(finite(raw.orientation, 0)),
        primaryOrientation: Math.round(finite(raw.primaryOrientation, 0)),
        lastSeen: Math.max(0, Math.round(finite(raw.lastSeen, 0))),
        positions: {}
    };

    for (var i = 0; i < PANELS.length; i++)
        record.positions[PANELS[i]] = sanitisePosition(PANELS[i], raw.positions && raw.positions[PANELS[i]]);

    return record;
}

function emptyState() {
    return {
        version: VERSION,
        outputs: {}
    };
}

function sanitise(state) {
    var result = emptyState();
    var source = state && typeof state === "object" ? state : {};
    var outputs = source.outputs && typeof source.outputs === "object" ? source.outputs : {};

    Object.keys(outputs).forEach(function(key) {
        var record = sanitiseRecord(outputs[key]);
        if (!record)
            return;
        // Prefer the record's own key, so a renamed object key cannot break the
        // mapping to a connector.
        result.outputs[record.key] = record;
    });

    return result;
}

function recordFor(description, now) {
    if (!description)
        return null;

    var record = sanitiseRecord({
        key: description.key,
        name: description.name,
        width: description.width,
        height: description.height,
        x: description.x,
        y: description.y,
        devicePixelRatio: description.devicePixelRatio,
        orientation: description.orientation,
        primaryOrientation: description.primaryOrientation,
        lastSeen: now
    });

    if (!record)
        return null;

    record.lastSeen = Math.max(0, Math.round(finite(now, 0)));
    return record;
}

// Keep every offline output so a monitor that comes back at the same connector
// restores its panel anchors.  Bound the file so a dock or a VM that cycles
// synthetic outputs cannot grow it forever.
function prune(state, maxOutputs) {
    var limit = Math.max(1, Math.round(finite(maxOutputs, MAX_OUTPUTS)));
    var records = Object.values(state.outputs);
    if (records.length <= limit)
        return state;

    records.sort(function(a, b) {
        return b.lastSeen - a.lastSeen;
    });
    var keep = {};
    records.slice(0, limit).forEach(function(record) {
        keep[record.key] = record;
    });
    state.outputs = keep;
    return state;
}

function reconcile(state, snapshotValue, now, maxOutputs) {
    var result = sanitise(state);
    var stamp = Math.max(0, Math.round(finite(now, Date.now())));
    var outputs = snapshotValue && Array.isArray(snapshotValue.outputs) ? snapshotValue.outputs : (Array.isArray(snapshotValue) ? snapshotValue : []);

    for (var i = 0; i < outputs.length; i++) {
        var description = outputs[i];
        if (!description)
            continue;
        var key = cleanKey(description.key || description.name);
        if (!key)
            continue;

        var previous = result.outputs[key];
        var record = recordFor(description, stamp);
        if (!record)
            continue;

        // Geometry is refreshed every time, but the panel positions belong to
        // the user and survive rotation, scaling and reconnects.
        if (previous && previous.positions)
            record.positions = clone(previous.positions);

        result.outputs[key] = record;
    }

    return prune(result, maxOutputs);
}

function targetKey(target) {
    if (!target)
        return "";
    if (typeof target === "string")
        return cleanKey(target);
    return cleanKey(target.key || target.name);
}

function restore(state, target) {
    var key = targetKey(target);
    var clean = sanitise(state);
    var record = clean.outputs[key];
    if (!record)
        return null;
    return clone(record);
}

function position(state, target, panel) {
    if (PANELS.indexOf(panel) < 0)
        return null;
    var record = restore(state, target);
    if (!record)
        return defaultPosition(panel);
    return record.positions[panel] || defaultPosition(panel);
}

function setPosition(state, target, panel, rawPosition) {
    if (PANELS.indexOf(panel) < 0)
        return sanitise(state);

    var key = targetKey(target);
    if (!key)
        return sanitise(state);

    var result = sanitise(state);
    var record = result.outputs[key];
    if (!record) {
        record = recordFor(target && typeof target === "object" ? target : { key: key, name: key }, Date.now());
        if (!record)
            return result;
        result.outputs[key] = record;
    }

    record.positions[panel] = sanitisePosition(panel, rawPosition);
    return result;
}

function forget(state, target) {
    var key = targetKey(target);
    var result = sanitise(state);
    if (key)
        delete result.outputs[key];
    return result;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        VERSION: VERSION,
        MAX_OUTPUTS: MAX_OUTPUTS,
        MAX_OFFSET: MAX_OFFSET,
        PANELS: PANELS,
        ANCHORS: ANCHORS,
        DEFAULTS: DEFAULTS,
        emptyState: emptyState,
        sanitise: sanitise,
        sanitisePosition: sanitisePosition,
        sanitiseRecord: sanitiseRecord,
        recordFor: recordFor,
        reconcile: reconcile,
        restore: restore,
        position: position,
        setPosition: setPosition,
        forget: forget
    };
}
