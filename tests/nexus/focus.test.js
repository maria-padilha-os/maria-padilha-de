#!/usr/bin/env node
// Transition contract for the page list and the setting rows.

const assert = require("node:assert/strict");
const focus = require("../../shell/modules/nexus/search/FocusNavigation.js");

let checks = 0;
function check(condition, message) {
    checks++;
    assert.ok(condition, message);
}

check(focus.clamp(-1, 3) === 0, "clamp keeps a negative index at the first row");
check(focus.clamp(9, 3) === 2, "clamp keeps an overflow index at the last row");
check(focus.clamp(1, 0) === -1, "an empty list has no selected row");
check(focus.step(-1, 3, 1) === 0, "Down from the search field selects the first result");
check(focus.step(-1, 3, -1) === 2, "Up from the search field selects the last result");
check(focus.step(0, 3, -1) === 0, "Up stops at the first result");
check(focus.step(2, 3, 1) === 2, "Down stops at the last result");
check(focus.step(0, 3, 1) === 1, "Down moves one result at a time");
check(focus.step(1, 3, -1) === 0, "Up moves one result at a time");
check(focus.step(0, 0, 1) === -1, "no result can be selected in an empty list");

const rows = ["brightness", "night-light", "rotation"];
check(focus.stepInList(rows, "brightness", 1) === 1, "setting rows move down");
check(focus.stepInList(rows, "rotation", 1) === 2, "setting row focus does not wrap at the end");
check(focus.stepInList(rows, "night-light", -1) === 0, "setting rows move up");
check(focus.stepInList(rows, null, 1) === 0, "focus without a current row starts at the top");
check(focus.stepInList(rows, null, -1) === 2, "reverse focus without a current row starts at the bottom");
check(focus.stepInList([], null, 1) === -1, "an empty row list reports no target");

console.log(`focus transition checks: ${checks} passed`);
