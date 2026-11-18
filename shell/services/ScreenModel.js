// Pure output/screen model shared by the shell and the Node tests.
//
// Quickshell recreates a ShellScreen object when an output is reconnected, and
// can briefly expose two objects for the same connector while a hotplug is
// settling.  The shell therefore never treats object identity or the index in
// Quickshell.screens as stable: an output is identified by its connector name
// (DP-1, HDMI-A-1, HEADLESS-1, ...).  This file keeps the deduplication,
// primary/active fallback and change detection in one place so both the QML
// bindings and tests use exactly the same rules.
//
// It deliberately knows nothing about windows, wallpapers or notifications.

function text(value, fallback) {
    if (value === undefined || value === null)
        return fallback || "";
    var result = String(value).trim();
    return result.length > 0 ? result : (fallback || "");
}

function number(value, fallback) {
    var parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
}

function integer(value, fallback) {
    return Math.round(number(value, fallback));
}

// Connector names are already unique; make the persisted key filesystem/HTML
// safe without changing the name used for Hyprland or per-monitor configs.
function keyFor(screen, index) {
    if (!screen)
        return "";

    var name = text(screen.name);
    if (name.length > 0) {
        var key = name.replace(/[^0-9A-Za-z._-]/g, "_");
        if (key === "__proto__" || key === "constructor" || key === "prototype")
            return "output-" + key;
        return key;
    }

    // A few nested/headless setups expose an empty connector name.  Keep those
    // outputs usable, but mark the key as synthetic so a real connector cannot
    // collide with it.
    var model = text(screen.model).replace(/[^0-9A-Za-z._-]/g, "_");
    var serial = text(screen.serialNumber).replace(/[^0-9A-Za-z._-]/g, "_");
    var suffix = model || serial || "unknown";
    return "output-" + suffix + "-" + integer(index, 0);
}

function describe(screen, index) {
    if (!screen)
        return null;

    var width = integer(screen.width, 0);
    var height = integer(screen.height, 0);
    var dpr = number(screen.devicePixelRatio, 1);
    if (!(dpr > 0))
        dpr = 1;

    return {
        key: keyFor(screen, index),
        name: text(screen.name),
        width: width,
        height: height,
        x: integer(screen.x, 0),
        y: integer(screen.y, 0),
        devicePixelRatio: dpr,
        orientation: integer(screen.orientation, 0),
        primaryOrientation: integer(screen.primaryOrientation, 0),
        logicalWidth: Math.round(width / dpr),
        logicalHeight: Math.round(height / dpr),
        fingerprint: [
            width,
            height,
            integer(screen.x, 0),
            integer(screen.y, 0),
            dpr,
            integer(screen.orientation, 0),
            integer(screen.primaryOrientation, 0)
        ].join("|")
    };
}

function snapshot(screens, enabled) {
    var selected = selectScreens(screens, enabled);
    var outputs = [];

    for (var i = 0; i < selected.length; i++) {
        var output = describe(selected[i], i);
        if (output)
            outputs.push(output);
    }

    return {
        outputs: outputs,
        keys: outputs.map(function(output) {
            return output.key;
        })
    };
}

// Filter disabled outputs and collapse duplicate connector entries.  A Map
// keeps the first position while replacing the value, so the newest object for
// a reconnected output wins without making the primary output jump around.
function selectScreens(screens, enabled) {
    var byKey = new Map();
    var list = screens || [];

    for (var i = 0; i < list.length; i++) {
        var screen = list[i];
        if (!screen)
            continue;
        if (typeof enabled === "function" && !enabled(screen))
            continue;

        var key = keyFor(screen, i);
        if (!key)
            continue;
        byKey.set(key, screen);
    }

    return Array.from(byKey.values());
}

function byName(screens, name) {
    var wanted = text(name);
    if (!wanted)
        return null;

    for (var i = 0; i < (screens || []).length; i++) {
        var screen = screens[i];
        if (screen && text(screen.name) === wanted)
            return screen;
    }
    return null;
}

// Pick the output keyboard/pointer actions should target.  A focused output
// wins; otherwise use the last remembered primary, then the first connected
// output.  Returning null for an empty model is intentional: callers can show
// a detached state instead of indexing a stale screen object.
function choosePrimary(candidates, options) {
    var settings = options || {};
    var list = candidates || [];
    if (list.length === 0)
        return null;

    var preferred = [
        settings.preferredKey,
        settings.preferredName,
        settings.focusedKey,
        settings.focusedName
    ];

    for (var p = 0; p < preferred.length; p++) {
        var wanted = text(preferred[p]);
        if (!wanted)
            continue;

        for (var i = 0; i < list.length; i++) {
            var item = list[i];
            var key = item.key !== undefined ? text(item.key) : keyFor(item, i);
            var name = item.name !== undefined ? text(item.name) : text(item.name);
            if (key === wanted || name === wanted)
                return item;
        }
    }

    return list[0];
}

function asOutputs(value) {
    if (Array.isArray(value))
        return value;
    if (value && Array.isArray(value.outputs))
        return value.outputs;
    return [];
}

function sameOutput(before, after) {
    return before && after && before.key === after.key && before.fingerprint === after.fingerprint;
}

// Return only what changed.  Consumers use the flags to decide whether a
// layout needs rewriting; a pure reorder is not a geometry change.
function diff(previous, next) {
    var before = asOutputs(previous);
    var after = asOutputs(next);
    var beforeByKey = new Map();
    var afterByKey = new Map();
    var added = [];
    var removed = [];
    var changed = [];
    var i;

    for (i = 0; i < before.length; i++)
        beforeByKey.set(before[i].key, before[i]);
    for (i = 0; i < after.length; i++)
        afterByKey.set(after[i].key, after[i]);

    for (i = 0; i < after.length; i++) {
        var now = after[i];
        var old = beforeByKey.get(now.key);
        if (!old) {
            added.push(now);
            continue;
        }
        if (sameOutput(old, now))
            continue;

        changed.push({
            key: now.key,
            before: old,
            after: now,
            moved: old.x !== now.x || old.y !== now.y,
            resized: old.width !== now.width || old.height !== now.height,
            scaled: old.devicePixelRatio !== now.devicePixelRatio,
            rotated: old.orientation !== now.orientation || old.primaryOrientation !== now.primaryOrientation
        });
    }

    for (i = 0; i < before.length; i++) {
        if (!afterByKey.has(before[i].key))
            removed.push(before[i]);
    }

    return {
        added: added,
        removed: removed,
        changed: changed,
        empty: after.length === 0,
        touched: added.length > 0 || removed.length > 0 || changed.length > 0
    };
}

function findOutput(snapshotValue, keyOrName) {
    var wanted = text(keyOrName);
    var outputs = asOutputs(snapshotValue);
    if (!wanted)
        return null;

    for (var i = 0; i < outputs.length; i++) {
        var output = outputs[i];
        if (output.key === wanted || output.name === wanted)
            return output;
    }
    return null;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        keyFor: keyFor,
        describe: describe,
        snapshot: snapshot,
        selectScreens: selectScreens,
        byName: byName,
        choosePrimary: choosePrimary,
        diff: diff,
        findOutput: findOutput
    };
}
