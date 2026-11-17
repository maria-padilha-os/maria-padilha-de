// Pure helpers shared by the Nexus search box and its Node tests.
// Kept as a plain JS module so `require()` can exercise the same ranking code.


// Pure ranking for the Nexus search box. The catalog supplies translated
// labels and descriptions; this file only decides which entries match and in
// what order, so it can be exercised without a display server.

function normalise(value) {
    let text = value === undefined || value === null ? "" : String(value).toLocaleLowerCase();
    try {
        text = text.normalize("NFKD").replace(/[\u0300-\u036f]/g, "");
    } catch (error) {
        // Older JS engines do not provide String.normalize; keep the raw text.
    }
    return text.replace(/\s+/g, " ").trim();
}

function isBoundary(character) {
    return character === "" || !/[0-9a-zA-Z\u00c0-\u024f]/.test(character);
}

function scoreField(value, term, weight) {
    const text = normalise(value);
    if (!text)
        return 0;

    const index = text.indexOf(term);
    if (index < 0)
        return 0;

    let score = weight;
    if (text === term)
        score += 320;
    else if (index === 0)
        score += 190;
    else if (isBoundary(text.charAt(index - 1)))
        score += 130;

    // A concise label is more useful than a long description that happens to
    // contain the same word. Keep the adjustment small so it only breaks ties.
    score += Math.max(0, 40 - Math.min(40, Math.round(text.length / 4)));
    return score;
}

function matchesTerm(entry, term) {
    return normalise(entry.label).indexOf(term) >= 0
        || normalise(entry.description).indexOf(term) >= 0
        || normalise(entry.pageTitle).indexOf(term) >= 0
        || normalise(entry.keywords).indexOf(term) >= 0;
}

function scoreEntry(entry, query) {
    const q = normalise(query);
    if (!q)
        return 0;

    const terms = q.split(" ").filter(term => term.length > 0);
    for (const term of terms) {
        if (!matchesTerm(entry, term))
            return 0;
    }

    let score = 0;
    for (const term of terms) {
        score += scoreField(entry.label, term, entry.kind === "page" ? 720 : 620);
        score += scoreField(entry.description, term, entry.kind === "page" ? 300 : 260);
        score += scoreField(entry.pageTitle, term, 150);
        score += scoreField(entry.keywords, term, 110);
    }

    const label = normalise(entry.label);
    if (label === q)
        score += entry.kind === "page" ? 500 : 420;
    else if (label.indexOf(q) === 0)
        score += 220;

    return score;
}

function rank(entries, query, limit) {
    const q = normalise(query);
    if (!q)
        return [];

    const scored = [];
    for (let i = 0; i < entries.length; i++) {
        const entry = entries[i];
        const score = scoreEntry(entry, q);
        if (score > 0)
            scored.push({
                entry: entry,
                score: score,
                order: entry.order === undefined ? i : entry.order,
                index: i
            });
    }

    scored.sort((a, b) => b.score - a.score || a.order - b.order || a.index - b.index);
    const capped = typeof limit === "number" && limit > 0 ? scored.slice(0, limit) : scored;
    return capped.map(result => Object.assign({}, result.entry, {
        score: result.score,
        order: result.order
    }));
}

function matchRanges(value, query) {
    const text = normalise(value);
    const ranges = [];
    const q = normalise(query);
    if (!text || !q)
        return ranges;

    for (const term of q.split(" ")) {
        if (!term)
            continue;
        let from = 0;
        while (from <= text.length) {
            const index = text.indexOf(term, from);
            if (index < 0)
                break;
            ranges.push({
                start: index,
                end: index + term.length
            });
            from = index + term.length;
        }
    }

    ranges.sort((a, b) => a.start - b.start || a.end - b.end);
    return ranges;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        normalise: normalise,
        scoreEntry: scoreEntry,
        rank: rank,
        matchRanges: matchRanges
    };
}
