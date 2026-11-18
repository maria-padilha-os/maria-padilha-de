#!/usr/bin/env node
// Screen-model and per-output layout contract.  These modules are imported by
// the shell, but their inputs and outputs are plain JavaScript, so monitor
// add/remove/rotate/scale can be exercised without a display server.

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const Model = require(path.join(__dirname, "..", "..", "shell", "services", "ScreenModel.js"));
const Layout = require(path.join(__dirname, "..", "..", "shell", "services", "OutputLayout.js"));

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

function screen(name, overrides) {
    return Object.assign({
        name: name,
        model: "Test Display",
        serialNumber: "SERIAL-" + name,
        x: 0,
        y: 0,
        width: 1920,
        height: 1080,
        devicePixelRatio: 1,
        orientation: 0,
        primaryOrientation: 0,
    }, overrides || {});
}

console.log("screen model");

test("the connector name is the stable key across rotation and scaling", () => {
    const before = Model.describe(screen("DP-1"), 0);
    const after = Model.describe(screen("DP-1", {
        width: 2560,
        height: 1440,
        devicePixelRatio: 1.5,
        orientation: 1,
    }), 3);
    assert.equal(before.key, "DP-1");
    assert.equal(after.key, "DP-1");
    assert.notEqual(before.fingerprint, after.fingerprint);
    assert.equal(after.logicalWidth, 1707);
    assert.equal(after.logicalHeight, 960);
});

test("an unnamed headless output still has a stable, non-empty key", () => {
    const unnamed = screen("", { model: "Headless", serialNumber: "" });
    const first = Model.describe(unnamed, 0);
    const again = Model.describe(unnamed, 0);
    assert.equal(first.key, "output-Headless-0");
    assert.equal(again.key, first.key);
    assert.equal(Model.keyFor({ name: "__proto__" }, 0), "output-__proto__");
});

test("duplicate connector entries collapse to the newest object in first position", () => {
    const old = screen("DP-1", { width: 1920 });
    const fresh = screen("DP-1", { width: 2560 });
    const selected = Model.selectScreens([old, screen("HDMI-A-1", { x: 1920 }), fresh]);
    assert.equal(selected.length, 2);
    assert.equal(selected[0], fresh);
    assert.equal(selected[1].name, "HDMI-A-1");
    assert.equal(Model.snapshot(selected).outputs.length, 2);
});

test("disabled and null outputs are filtered", () => {
    const selected = Model.selectScreens([
        screen("DP-1"),
        null,
        screen("DP-2"),
    ], output => output.name !== "DP-2");
    assert.deepEqual(selected.map(output => output.name), ["DP-1"]);
});

test("primary falls back from focus to the first remaining output to null", () => {
    const outputs = [screen("DP-1"), screen("HDMI-A-1", { x: 1920 })];
    assert.equal(Model.choosePrimary(outputs, { focusedName: "HDMI-A-1" }).name, "HDMI-A-1");
    assert.equal(Model.choosePrimary(outputs, { focusedName: "GONE-1" }).name, "DP-1");
    assert.equal(Model.choosePrimary(outputs, {}).name, "DP-1");
    assert.equal(Model.choosePrimary([], { focusedName: "DP-1" }), null);
});

test("removing the focused output updates the model and primary without throwing", () => {
    const before = Model.snapshot([screen("DP-1"), screen("HDMI-A-1", { x: 1920 })]);
    const after = Model.snapshot([screen("HDMI-A-1")]);
    const change = Model.diff(before, after);

    assert.deepEqual(change.added, []);
    assert.deepEqual(change.removed.map(output => output.key), ["DP-1"]);
    assert.equal(change.empty, false);
    assert.equal(Model.choosePrimary(after.outputs, { focusedName: "DP-1" }).key, "HDMI-A-1");
});

test("rotation, scale, movement and resize are reported separately", () => {
    const before = Model.snapshot([screen("DP-1")]);
    const after = Model.snapshot([screen("DP-1", {
        x: 100,
        y: 50,
        width: 2560,
        height: 1440,
        devicePixelRatio: 1.5,
        orientation: 1,
    })]);
    const change = Model.diff(before, after).changed[0];

    assert.equal(change.moved, true);
    assert.equal(change.resized, true);
    assert.equal(change.scaled, true);
    assert.equal(change.rotated, true);
});

test("a pure reorder is not a screen-model change", () => {
    const first = screen("DP-1");
    const second = screen("HDMI-A-1", { x: 1920 });
    const before = Model.snapshot([first, second]);
    const after = Model.snapshot([second, first]);
    assert.equal(Model.diff(before, after).touched, false);
});

test("removing the last output returns an empty model and diff", () => {
    const before = Model.snapshot([screen("DP-1")]);
    const after = Model.snapshot([]);
    const change = Model.diff(before, after);
    assert.equal(after.outputs.length, 0);
    assert.equal(change.empty, true);
    assert.deepEqual(change.removed.map(output => output.key), ["DP-1"]);
    assert.equal(Model.choosePrimary(after.outputs, {}), null);
});

console.log("per-output layout");

test("layout records keep geometry but never screen contents", () => {
    const snapshot = Model.snapshot([screen("DP-1")]);
    const state = Layout.reconcile(Layout.emptyState(), snapshot, 1000);
    const record = state.outputs["DP-1"];

    assert.equal(record.width, 1920);
    assert.equal(record.height, 1080);
    assert.deepEqual(record.positions.bar, { edge: "right", offsetX: 0 });
    assert.deepEqual(record.positions.launcher, { anchor: "bottom-center", offsetX: 0, offsetY: 0 });

    const text = JSON.stringify(state);
    for (const forbidden of ["screenshot", "thumbnail", "image", "wallpaperPath", "windowTitle", "pixels", "contents"]) {
        assert.equal(text.includes(forbidden), false, `state leaked ${forbidden}`);
    }
});

test("a rotated or scaled output keeps its saved panel positions", () => {
    let state = Layout.reconcile(Layout.emptyState(), Model.snapshot([screen("DP-1")]), 1000);
    state = Layout.setPosition(state, { key: "DP-1" }, "bar", { edge: "left", offsetX: 32 });
    state = Layout.setPosition(state, { key: "DP-1" }, "dashboard", { anchor: "bottom-right", offsetY: -12 });
    state = Layout.reconcile(state, Model.snapshot([screen("DP-1", {
        width: 2560,
        height: 1440,
        devicePixelRatio: 1.5,
        orientation: 1,
    })]), 2000);

    assert.equal(state.outputs["DP-1"].width, 2560);
    assert.equal(state.outputs["DP-1"].devicePixelRatio, 1.5);
    assert.equal(state.outputs["DP-1"].orientation, 1);
    assert.deepEqual(state.outputs["DP-1"].positions.bar, { edge: "left", offsetX: 32 });
    assert.deepEqual(state.outputs["DP-1"].positions.dashboard, { anchor: "bottom-right", offsetX: 0, offsetY: -12 });
});

test("an output can disappear and come back with the same positions", () => {
    const first = { key: "DP-1", name: "DP-1", width: 1920, height: 1080 };
    let state = Layout.reconcile(Layout.emptyState(), Model.snapshot([screen("DP-1")]), 1000);
    state = Layout.setPosition(state, first, "notifications", { anchor: "middle-right", offsetX: 8 });
    state = Layout.reconcile(state, Model.snapshot([]), 2000);

    assert.ok(state.outputs["DP-1"], "offline output is retained");
    assert.equal(Layout.position(state, first, "notifications").anchor, "middle-right");

    state = Layout.reconcile(state, Model.snapshot([screen("DP-1")]), 3000);
    assert.deepEqual(Layout.position(state, "DP-1", "notifications"), { anchor: "middle-right", offsetX: 8, offsetY: 0 });
});

test("unknown and private keys are dropped when a layout is loaded", () => {
    const state = Layout.sanitise({
        version: 99,
        privateScreenContents: "base64...",
        outputs: {
            "DP-1": {
                key: "DP-1",
                name: "DP-1",
                width: 1920,
                height: 1080,
                screenshot: "data:image/png;base64,AAAA",
                windowTitle: "private window",
                positions: {
                    bar: { edge: "left", offsetX: 10, screenshot: "AAAA" },
                    notifications: { anchor: "elsewhere", offsetX: 999999 },
                },
            },
        },
    });

    assert.equal(state.version, Layout.VERSION);
    assert.equal("privateScreenContents" in state, false);
    assert.deepEqual(state.outputs["DP-1"].positions.bar, { edge: "left", offsetX: 10 });
    assert.deepEqual(state.outputs["DP-1"].positions.notifications, { anchor: "top-right", offsetX: Layout.MAX_OFFSET, offsetY: 0 });
    assert.equal(JSON.stringify(state).includes("data:image"), false);
    assert.equal(JSON.stringify(state).includes("private window"), false);
});

test("offsets are clamped and unknown panels are rejected", () => {
    const state = Layout.setPosition(Layout.emptyState(), "DP-1", "bar", { edge: "diagonal", offsetX: -999999 });
    assert.deepEqual(Layout.position(state, "DP-1", "bar"), { edge: "right", offsetX: -Layout.MAX_OFFSET });
    assert.equal(Layout.position(state, "DP-1", "not-a-panel"), null);
});

test("forgetting an output removes only that record", () => {
    let state = Layout.reconcile(Layout.emptyState(), Model.snapshot([
        screen("DP-1"),
        screen("HDMI-A-1", { x: 1920 }),
    ]), 1000);
    state = Layout.forget(state, "DP-1");
    assert.equal("DP-1" in state.outputs, false);
    assert.equal("HDMI-A-1" in state.outputs, true);
});

test("the state file is bounded when synthetic outputs cycle", () => {
    let state = Layout.emptyState();
    for (let i = 0; i < Layout.MAX_OUTPUTS + 5; i++) {
        state = Layout.reconcile(state, Model.snapshot([screen(`HEADLESS-${i}`)]), 1000 + i);
        state = Layout.reconcile(state, Model.snapshot([]), 1000 + i);
    }
    assert.equal(Object.keys(state.outputs).length, Layout.MAX_OUTPUTS);
    assert.ok(state.outputs[`HEADLESS-${Layout.MAX_OUTPUTS + 4}`], "newest output is kept");
});

if (process.exitCode && process.exitCode !== 0)
    process.exit(process.exitCode);
console.log(`\n${passed} screen-model and layout checks passed`);
