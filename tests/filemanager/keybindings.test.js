#!/usr/bin/env node
"use strict";

// Node-side contract for the Files Vim table. The same file is imported by
// Widget.qml, so this catches a broken table even when no display is available.

const assert = require("node:assert/strict");
const path = require("node:path");

const table = require(path.join(__dirname, "..", "..", "extensions", "filemanager", "Keybindings.js"));

function test(name, fn) {
    try {
        fn();
        console.log(`  ok   ${name}`);
    } catch (error) {
        console.log(`  FAIL ${name}`);
        console.log(`       ${error.message}`);
        process.exitCode = 1;
    }
}

function action(token, ctrl = false, shift = false, pending = "") {
    return table.resolve(token, ctrl, shift, pending);
}

test("binding table exposes the Vim contract", () => {
    const labels = table.bindings.map(binding => binding.label);
    for (const expected of ["j", "k", "h", "l", "gg", "G", "Ctrl+d", "Ctrl+u", "/", "Esc", "Enter"])
        assert.ok(labels.includes(expected), `missing ${expected}`);
    assert.equal(table.modeLabels.normal, "NORMAL");
    assert.equal(table.modeLabels.search, "SEARCH");
});

test("j/k move, h/l navigate and open", () => {
    assert.equal(action("j").action, "moveDown");
    assert.equal(action("k").action, "moveUp");
    assert.equal(action("h").action, "goUp");
    assert.equal(action("l").action, "open");
    assert.equal(action("Enter").action, "open");
    assert.equal(action("Backspace").action, "goUp");
});

test("gg is a sequence and G is the last-entry jump", () => {
    const firstG = action("g");
    assert.equal(firstG.action, "");
    assert.equal(firstG.pending, "g");
    assert.equal(firstG.consume, true);

    const secondG = action("g", false, false, firstG.pending);
    assert.equal(secondG.action, "first");
    assert.equal(secondG.pending, "");

    assert.equal(action("G", false, true).action, "last");

    // A different key after the first g cancels the prefix and still works.
    assert.equal(action("j", false, false, firstG.pending).action, "moveDown");
});

test("Ctrl+d/Ctrl+u page without falling through to letters", () => {
    assert.equal(action("d", true).action, "pageDown");
    assert.equal(action("u", true).action, "pageUp");
    assert.equal(action("d").action, "");
    assert.equal(action("u").action, "");
});

test("slash opens search and Escape clears it", () => {
    assert.equal(action("/").action, "search");
    assert.equal(action("Escape").action, "escape");
});

test("no destructive key is bound", () => {
    for (const binding of table.bindings) {
        assert.equal(table.isDestructive(binding.action), false,
            `${binding.label} unexpectedly maps to ${binding.action}`);
        if (table.isDestructive(binding.action))
            assert.equal(binding.requiresConfirm, true, `${binding.label} needs confirmation`);
    }
    assert.ok(table.destructiveActions.includes("delete"));
});

if (process.exitCode && process.exitCode !== 0)
    process.exit(process.exitCode);
console.log("\nkeybinding table checks passed");
