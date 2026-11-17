#!/usr/bin/env node
// Unit tests for shell/services/ExtensionManifest.js. This module is imported
// by the shell, but its inputs and outputs are plain JavaScript, so the whole
// validation, duplicate and persistence contract can run without Qt.

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const Manifest = require(path.join(__dirname, "..", "..", "shell", "services", "ExtensionManifest.js"));

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

function manifest(overrides) {
    return Object.assign({
        name: "Demo",
        description: "A demo extension",
        version: "1.0",
        icon: "extension",
        tab: "Tab.qml",
    }, overrides || {});
}

function body(overrides) {
    return JSON.stringify(manifest(overrides));
}

function catalog(entries) {
    return Manifest.buildCatalog(entries, { availableCommands: {} });
}

console.log("manifest validation");

test("a complete manifest is valid and enableable", () => {
    const [entry] = catalog([{
        dirPath: "/tmp/extensions/demo",
        body: body({ shortcut: "Super + Alt + D", permissions: ["network"] }),
        files: ["Tab.qml", "Widget.qml"],
    }]);
    assert.equal(entry.id, "demo");
    assert.equal(entry.name, "Demo");
    assert.equal(entry.valid, true);
    assert.equal(entry.canEnable, true);
    assert.deepEqual(entry.permissions, ["network"]);
    assert.equal(entry.tabExists, true);
    assert.equal(entry.tabUrl, "file:///tmp/extensions/demo/Tab.qml");
});

test("invalid JSON is kept as an entry with an actionable error", () => {
    const [entry] = catalog([{
        dirPath: "/tmp/extensions/broken",
        body: "{\"name\": \"Broken\",}",
        files: ["Tab.qml"],
    }]);
    assert.equal(entry.id, "broken");
    assert.equal(entry.valid, false);
    assert.equal(entry.canEnable, false);
    assert.match(entry.errors.join(" "), /not valid JSON/i);
    assert.match(entry.errors.join(" "), /fix/i);
});

test("an empty manifest is not silently hidden", () => {
    const [entry] = catalog([{ dirPath: "/tmp/extensions/empty", body: "  ", files: [] }]);
    assert.equal(entry.id, "empty");
    assert.equal(entry.valid, false);
    assert.match(entry.errors.join(" "), /empty/i);
});

test("a non-object manifest is rejected", () => {
    const [entry] = catalog([{ dirPath: "/tmp/extensions/array", body: "[]", files: [] }]);
    assert.equal(entry.valid, false);
    assert.match(entry.errors.join(" "), /JSON object/i);
});

test("required fields are non-empty strings", () => {
    const [entry] = catalog([{
        dirPath: "/tmp/extensions/missing",
        body: JSON.stringify({ name: "Missing", tab: "Tab.qml" }),
        files: ["Tab.qml"],
    }]);
    assert.equal(entry.valid, false);
    for (const field of ["description", "version", "icon"])
        assert.match(entry.errors.join(" "), new RegExp(`"${field}" is required`));
});

test("unsafe tab paths are rejected", () => {
    for (const tab of ["../Tab.qml", "/tmp/Tab.qml", "sub/../../Tab.qml", "Tab.txt"]) {
        const [entry] = catalog([{ dirPath: "/tmp/extensions/unsafe", body: body({ tab }), files: [tab] }]);
        assert.equal(entry.valid, false, tab);
        assert.match(entry.errors.join(" "), /"tab"/, tab);
    }
});

test("a missing tab file is an error on the card", () => {
    const [entry] = catalog([{
        dirPath: "/tmp/extensions/nofile",
        body: body(),
        files: ["Widget.qml"],
    }]);
    assert.equal(entry.tabExists, false);
    assert.equal(entry.valid, false);
    assert.equal(entry.canEnable, false);
    assert.match(entry.errors.join(" "), /Tab file "Tab\.qml" was not found/);
});

test("permissions and the capabilities alias are merged", () => {
    const [entry] = catalog([{
        dirPath: "/tmp/extensions/cap",
        body: body({ permissions: ["network", "network"], capabilities: ["clipboard"] }),
        files: ["Tab.qml"],
    }]);
    assert.deepEqual(entry.permissions, ["network", "clipboard"]);
    assert.match(entry.warnings.join(" "), /more than once/);
});

test("an unknown permission is shown but does not block enabling", () => {
    const [entry] = catalog([{
        dirPath: "/tmp/extensions/custom",
        body: body({ permissions: ["telepathy"] }),
        files: ["Tab.qml"],
    }]);
    assert.equal(entry.valid, true);
    assert.equal(entry.canEnable, true);
    assert.match(entry.warnings.join(" "), /Unknown permission "telepathy"/);
});

test("scanner output keeps every folder and checks the tab file list", () => {
    const output = [
        `EXTENSION:/tmp/extensions/good/\nFILES:Tab.qml\tWidget.qml\t\n${body({ name: "Good" })}\n`,
        `EXTENSION:/tmp/extensions/broken/\nFILES:Widget.qml\t\n${body({ name: "Broken" })}\n`,
        "EXTENSION:/tmp/extensions/json/\nFILES:Tab.qml\t\n{\"name\": \"Json\",}\n",
    ].join("");
    const entries = Manifest.catalogFromScan(output);
    assert.equal(entries.length, 3);
    const good = entries.find(entry => entry.id === "good");
    const broken = entries.find(entry => entry.id === "broken");
    const invalidJson = entries.find(entry => entry.id === "json");
    assert.equal(good.canEnable, true);
    assert.equal(good.tabExists, true);
    assert.equal(broken.canEnable, false);
    assert.match(broken.errors.join(" "), /Tab file "Tab\.qml" was not found/);
    assert.equal(invalidJson.valid, false);
    assert.match(invalidJson.errors.join(" "), /not valid JSON/);
});

test("scanner output without a file list still parses the manifest", () => {
    const [entry] = Manifest.catalogFromScan(`EXTENSION:/tmp/extensions/legacy/\n${body()}\n`);
    assert.equal(entry.id, "legacy");
    assert.equal(entry.valid, true);
    assert.equal(entry.tabExists, null);
});

test("scanner command availability marks only the missing command", () => {
    const output = `EXTENSION:/tmp/extensions/demo/\nPRIORITY:2\nFILES:Tab.qml\t\nCOMMANDS:qalc=/usr/bin/qalc\tmissing=\n${body({ commands: ["qalc", "missing"] })}\n`;
    const [entry] = Manifest.catalogFromScan(output);
    assert.equal(entry.priority, 2);
    assert.deepEqual(entry.missingCommands, ["missing"]);
    assert.equal(entry.canEnable, false);
    assert.match(entry.errors.join(" "), /Missing command "missing"/);
});

test("an unknown command availability sentinel does not invent a missing dependency", () => {
    const output = `EXTENSION:/tmp/extensions/demo/\nFILES:Tab.qml\t\nCOMMANDS:?\n${body({ commands: ["not-checked"] })}\n`;
    const [entry] = Manifest.catalogFromScan(output);
    assert.deepEqual(entry.missingCommands, []);
    assert.equal(entry.canEnable, true);
});

console.log("duplicate ids and shortcuts");

test("duplicate ids at the same priority are rejected", () => {
    const entries = catalog([
        { dirPath: "/tmp/user/extensions/demo", priority: 1, body: body({ name: "User demo" }), files: ["Tab.qml"] },
        { dirPath: "/usr/share/extensions/demo", priority: 1, body: body({ name: "Bundled demo" }), files: ["Tab.qml"] },
    ]);
    assert.equal(entries.length, 2);
    for (const entry of entries) {
        assert.equal(entry.id, "demo");
        assert.equal(entry.duplicateId, true);
        assert.equal(entry.shadowed, false);
        assert.equal(entry.valid, false);
        assert.equal(entry.canEnable, false);
        assert.match(entry.errors.join(" "), /Duplicate extension id "demo"/);
        assert.match(entry.errors.join(" "), /Rename or remove one folder/);
    }
});

test("a user copy shadows a bundled duplicate without breaking the override", () => {
    const entries = catalog([
        {
            dirPath: "/tmp/user/extensions/demo",
            priority: 1,
            body: body({ name: "User demo", shortcut: "Super + Alt + U" }),
            files: ["Tab.qml"],
        },
        {
            dirPath: "/usr/share/extensions/demo",
            priority: 4,
            body: body({ name: "Bundled demo", shortcut: "Super + Alt + U" }),
            files: ["Tab.qml"],
        },
    ]);
    const user = entries.find(entry => entry.dirPath === "/tmp/user/extensions/demo");
    const bundled = entries.find(entry => entry.dirPath === "/usr/share/extensions/demo");

    assert.equal(user.duplicateId, true);
    assert.equal(user.shadowed, false);
    assert.equal(user.valid, true);
    assert.equal(user.canEnable, true);
    assert.match(user.warnings.join(" "), /Overrides the same id "demo"/);

    assert.equal(bundled.duplicateId, true);
    assert.equal(bundled.shadowed, true);
    assert.equal(bundled.valid, true);
    assert.equal(bundled.canEnable, false);
    assert.match(bundled.warnings.join(" "), /Shadowed by \/tmp\/user\/extensions\/demo/);

    // A shadowed copy must not create a second shortcut conflict.
    assert.equal(user.shortcutConflict, false);
    assert.equal(bundled.shortcutConflict, false);
});

test("duplicate shortcuts are normalised and reported on both entries", () => {
    const entries = catalog([
        { dirPath: "/tmp/extensions/alpha", body: body({ name: "Alpha", shortcut: "Super + Alt + X" }), files: ["Tab.qml"] },
        { dirPath: "/tmp/extensions/bravo", body: body({ name: "Bravo", shortcut: "super+alt+x" }), files: ["Tab.qml"] },
    ]);
    assert.equal(entries.length, 2);
    for (const entry of entries) {
        assert.equal(entry.shortcutConflict, true);
        assert.equal(entry.valid, true);
        assert.equal(entry.canEnable, true);
        assert.match(entry.warnings.join(" "), /Shortcut ".*" is also used by/);
    }
    assert.match(entries.find(entry => entry.id === "alpha").warnings.join(" "), /Bravo \(bravo\)/);
});

test("different shortcuts are not flagged", () => {
    const entries = catalog([
        { dirPath: "/tmp/extensions/alpha", body: body({ shortcut: "Super + Alt + X" }), files: ["Tab.qml"] },
        { dirPath: "/tmp/extensions/bravo", body: body({ shortcut: "Super + Alt + Y" }), files: ["Tab.qml"] },
    ]);
    assert.equal(entries[0].shortcutConflict, false);
    assert.equal(entries[1].shortcutConflict, false);
});

console.log("dependencies and commands");

test("a present extension dependency is reported as present", () => {
    const entries = catalog([
        { dirPath: "/tmp/extensions/base", body: body({ requires: ["helper"] }), files: ["Tab.qml"] },
        { dirPath: "/tmp/extensions/helper", body: body({ name: "Helper" }), files: ["Tab.qml"] },
    ]);
    const base = entries.find(entry => entry.id === "base");
    assert.deepEqual(base.requires, ["helper"]);
    assert.deepEqual(base.missingDependencies, []);
    assert.deepEqual(base.dependencies, [{ id: "helper", present: true }]);
    assert.equal(base.canEnable, true);
});

test("a missing extension dependency blocks enabling with a fix", () => {
    const [entry] = catalog([{
        dirPath: "/tmp/extensions/base",
        body: body({ requires: ["missing"] }),
        files: ["Tab.qml"],
    }]);
    assert.deepEqual(entry.missingDependencies, ["missing"]);
    assert.equal(entry.valid, false);
    assert.equal(entry.canEnable, false);
    assert.match(entry.errors.join(" "), /Missing extension dependency: missing/);
    assert.match(entry.errors.join(" "), /nothing is downloaded automatically/);
});

test("a missing local command is detected when availability is known", () => {
    const entries = Manifest.buildCatalog([
        { dirPath: "/tmp/extensions/base", body: body({ commands: ["qalc"] }), files: ["Tab.qml"] },
    ], { availableCommands: { qalc: false } });
    assert.deepEqual(entries[0].missingCommands, ["qalc"]);
    assert.equal(entries[0].canEnable, false);
    assert.match(entries[0].errors.join(" "), /Missing command "qalc"/);
});

test("a present local command does not block enabling", () => {
    const entries = Manifest.buildCatalog([
        { dirPath: "/tmp/extensions/base", body: body({ commands: ["qalc"] }), files: ["Tab.qml"] },
    ], { availableCommands: { qalc: "/usr/bin/qalc" } });
    assert.deepEqual(entries[0].missingCommands, []);
    assert.equal(entries[0].canEnable, true);
});

console.log("enable/disable persistence");

test("enabling appends the id exactly once", () => {
    let ids = [];
    ids = Manifest.setEnabled(ids, "notes", true);
    assert.deepEqual(ids, ["notes"]);
    ids = Manifest.setEnabled(ids, "notes", true);
    assert.deepEqual(ids, ["notes"]);
});

test("disabling removes the id and keeps the other order", () => {
    let ids = Manifest.setEnabled([], "notes", true);
    ids = Manifest.setEnabled(ids, "calendar", true);
    ids = Manifest.setEnabled(ids, "notes", false);
    assert.deepEqual(ids, ["calendar"]);
    assert.equal(Manifest.isEnabled(ids, "notes"), false);
    assert.equal(Manifest.isEnabled(ids, "calendar"), true);
});

test("the enabled list survives a JSON persistence round trip", () => {
    const written = Manifest.setEnabled(["calculator"], "notes", true);
    const persisted = JSON.parse(JSON.stringify(written));
    assert.deepEqual(persisted, ["calculator", "notes"]);
    assert.equal(Manifest.isEnabled(persisted, "notes"), true);
    const afterRestart = Manifest.setEnabled(persisted, "notes", false);
    assert.deepEqual(afterRestart, ["calculator"]);
    assert.equal(Manifest.isEnabled(afterRestart, "notes"), false);
});

test("a malformed stored list is normalised instead of crashing", () => {
    assert.deepEqual(Manifest.setEnabled(null, "notes", true), ["notes"]);
    assert.deepEqual(Manifest.setEnabled([1, "", "notes"], "calendar", true), ["notes", "calendar"]);
    assert.equal(Manifest.isEnabled(undefined, "notes"), false);
});

console.log("search and filter");

test("search matches names, descriptions, permissions and errors", () => {
    const entries = catalog([
        { dirPath: "/tmp/extensions/notes", body: body({ name: "Notes", description: "Plain text", permissions: ["filesystem"] }), files: ["Tab.qml"] },
        { dirPath: "/tmp/extensions/maps", body: body({ name: "Maps", description: "Map viewer", permissions: ["network"] }), files: ["Tab.qml"] },
    ]);
    assert.deepEqual(Manifest.filterCatalog(entries, "text", "all").map(entry => entry.id), ["notes"]);
    assert.deepEqual(Manifest.filterCatalog(entries, "network", "all").map(entry => entry.id), ["maps"]);
    assert.deepEqual(Manifest.filterCatalog(entries, "maps", "all").map(entry => entry.id), ["maps"]);
    assert.deepEqual(Manifest.filterCatalog(entries, "", "all").length, 2);
});

test("enabled, disabled and issues filters use the live enabled flag", () => {
    const entries = catalog([
        { dirPath: "/tmp/extensions/one", body: body({ name: "One" }), files: ["Tab.qml"] },
        { dirPath: "/tmp/extensions/two", body: body({ name: "Two" }), files: ["Tab.qml"] },
        { dirPath: "/tmp/extensions/three", body: "broken", files: [] },
    ]);
    const withState = entries.map(entry => Object.assign({}, entry, { enabled: entry.id === "one" }));
    assert.deepEqual(Manifest.filterCatalog(withState, "", "enabled").map(entry => entry.id), ["one"]);
    assert.deepEqual(Manifest.filterCatalog(withState, "", "disabled").map(entry => entry.id).sort(), ["three", "two"]);
    assert.deepEqual(Manifest.filterCatalog(withState, "", "issues").map(entry => entry.id), ["three"]);
});

if (process.exitCode && process.exitCode !== 0)
    process.exit(process.exitCode);
console.log(`\n${passed} manifest and persistence checks passed`);
