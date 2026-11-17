#!/usr/bin/env node
// Ranking contract for the Nexus search box. These are the same pure functions
// the QML singleton calls, so a regression here is a visible UI regression.

const assert = require("node:assert/strict");
const ranking = require("../../shell/modules/nexus/search/SearchRanking.js");

const entries = [
    {
        kind: "setting",
        pageIdx: 1,
        subPageIdx: -1,
        label: "Night light",
        description: "Warm tint after sunset",
        pageTitle: "Display",
        keywords: "blue light",
        order: 0
    },
    {
        kind: "setting",
        pageIdx: 1,
        subPageIdx: -1,
        label: "Brightness",
        description: "Screen brightness and night light warmth",
        pageTitle: "Display",
        keywords: "",
        order: 1
    },
    {
        kind: "page",
        pageIdx: 1,
        subPageIdx: -1,
        label: "Display",
        description: "Brightness, night light, monitor",
        pageTitle: "Display",
        keywords: "connectivity",
        order: 2
    },
    {
        kind: "setting",
        pageIdx: 12,
        subPageIdx: -1,
        label: "UI language",
        description: "The language used in the shell UI",
        pageTitle: "Language & region",
        keywords: "locale translation",
        order: 3
    },
    {
        kind: "setting",
        pageIdx: 3,
        subPageIdx: -1,
        label: "Discoverable",
        description: "Allow nearby devices to find this one",
        pageTitle: "Connected devices",
        keywords: "bluetooth",
        order: 4
    }
];

let checks = 0;
function check(condition, message) {
    checks++;
    assert.ok(condition, message);
}

function labels(query) {
    return ranking.rank(entries, query).map(result => result.label);
}

check(ranking.rank(entries, "").length === 0, "empty search returns no results");
check(ranking.rank(entries, "   ").length === 0, "whitespace-only search returns no results");
check(ranking.rank(entries, "no-such-setting").length === 0, "no results when nothing matches");

const pageResults = labels("display");
check(pageResults[0] === "Display", "a page title outranks settings that mention it");
check(pageResults.includes("Night light"), "page title also finds the settings on that page");

const nightResults = labels("night light");
check(nightResults[0] === "Night light", "an exact label outranks description-only matches");
check(nightResults.includes("Brightness"), "multi-term search matches descriptions");

const lightResults = labels("light");
check(lightResults[0] === "Night light", "a label word match outranks an interior description match");

const languageResults = labels("LANGUAGE");
check(languageResults[0] === "UI language", "search is case-insensitive");

const accentResults = ranking.rank([
    { kind: "setting", label: "Café", description: "Coffee", pageTitle: "Food", order: 0 },
    { kind: "setting", label: "Cafe", description: "Coffee", pageTitle: "Food", order: 1 }
], "cafe");
check(accentResults.length === 2, "diacritics are ignored while searching");
check(accentResults[0].label === "Café", "accent-normalised exact match wins");

const descriptionResults = labels("sunset");
check(descriptionResults[0] === "Night light", "description text is searchable");

const keywordResults = labels("bluetooth");
check(keywordResults.some(result => result === "Discoverable"), "keywords widen the page and setting search");

const combined = labels("language shell");
check(combined[0] === "UI language", "every query term must match the same entry");

const limited = ranking.rank(entries, "e", 2);
check(limited.length === 2, "result limits are respected");

const ranges = ranking.matchRanges("Night light settings", "light");
check(ranges.length === 1 && ranges[0].start === 6 && ranges[0].end === 11, "match ranges point at the query text");

const stable = ranking.rank([
    { kind: "setting", label: "Same", description: "", pageTitle: "", order: 2 },
    { kind: "setting", label: "Same", description: "", pageTitle: "", order: 1 }
], "same");
check(stable[0].order === 1 && stable[1].order === 2, "ties fall back to catalog order");

console.log(`search ranking checks: ${checks} passed`);
