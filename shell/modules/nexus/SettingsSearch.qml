pragma Singleton

import QtQuick
import qs.modules.nexus
import "search/SearchRanking.js" as Ranking

// Builds the searchable view of the settings tree: every page (including the
// StackView sub-pages) and every labelled setting from SettingsCatalog.
QtObject {
    id: root

    readonly property int resultLimit: 40

    readonly property var entries: {
        const result = [];
        const seenSettings = new Set();
        const seenSubPages = new Set();

        function add(entry, subPageIdx) {
            const sub = subPageIdx > 0 ? subPageIdx : -1;
            const key = `${entry.pageIdx}|${sub}|${entry.label}`;
            if (entry.kind === "setting") {
                if (seenSettings.has(key))
                    return;
                seenSettings.add(key);
            } else if (seenSubPages.has(key)) {
                return;
            } else {
                seenSubPages.add(key);
            }

            result.push(Object.assign({}, entry, {
                subPageIdx: sub,
                pageTitle: PageRegistry.pages[entry.pageIdx]?.label ?? "",
                keywords: entry.keywords ?? entry.description ?? "",
                order: result.length
            }));
        }

        for (let i = 0; i < PageRegistry.pages.length; i++) {
            const page = PageRegistry.pages[i];
            add({
                kind: "page",
                pageIdx: i,
                subPageIdx: -1,
                label: page.label,
                description: page.description,
                keywords: page.category
            }, -1);
        }

        for (const subPage of SettingsCatalog.subPages)
            add(Object.assign({ kind: "page" }, subPage), subPage.subPageIdx);

        for (const setting of SettingsCatalog.settings)
            add(Object.assign({ kind: "setting" }, setting), setting.subPageIdx);

        return result;
    }

    function search(query: string, limit: int): var {
        return Ranking.rank(root.entries, query, limit > 0 ? limit : root.resultLimit);
    }

    function normalise(value: string): string {
        return Ranking.normalise(value);
    }

    function matchRanges(value: string, query: string): var {
        return Ranking.matchRanges(value, query);
    }
}
