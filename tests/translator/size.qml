import QtQuick
import QtQuick.Window
import Quickshell

// Loads the translator tab at the compact 480x280 size, a short full-width
// dashboard and a roomy dashboard, then checks that the language row, source,
// result and footer do not overlap or leave the tab. `active` stays false so no
// clipboard, network or notification work starts.
Window {
    id: harness

    readonly property string tabPath: Quickshell.env("PADILHA_TRANSLATOR_TAB") || ""
    readonly property var palette: ({
            m3surface: "#141218",
            m3surfaceContainerHigh: "#2B2930",
            m3onSurface: "#E6E0E9",
            m3onSurfaceVariant: "#CAC4D0",
            m3outline: "#938F99",
            m3primary: "#D0BCFF",
            m3onPrimary: "#381E72",
            m3error: "#F2B8B5"
        })
    readonly property var cases: [
        {
            name: "compact 480x280",
            width: 480,
            height: 280,
            compact: true
        },
        {
            name: "full dashboard 1000x320",
            width: 1000,
            height: 320,
            compact: true
        },
        {
            name: "roomy dashboard 1000x600",
            width: 1000,
            height: 600,
            compact: false
        }
    ]
    readonly property string longText: "The quick brown fox jumps over the lazy dog. ".repeat(30)

    property int caseIndex: -1
    property var currentCase: null
    property var item: null
    property int failures: 0

    visible: true
    width: 1100
    height: 700
    color: harness.palette.m3surface

    function fakeApi(): var {
        return {
            config: {},
            colours: {
                palette: harness.palette
            },
            brightness: null,
            hypr: null,
            paths: {
                home: Quickshell.env("HOME") || "/tmp",
                cache: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") || "/tmp") + "/.cache")
            },
            extension: {}
        };
    }

    function findByName(object: var, name: string): var {
        if (!object)
            return null;
        if (object.objectName === name)
            return object;

        const children = object.children || [];
        for (let i = 0; i < children.length; i++) {
            const found = harness.findByName(children[i], name);
            if (found)
                return found;
        }
        return null;
    }

    function rectInRoot(node: var): var {
        const point = node.mapToItem(harness.item, 0, 0);
        return {
            x: point.x,
            y: point.y,
            width: node.width,
            height: node.height,
            right: point.x + node.width,
            bottom: point.y + node.height
        };
    }

    function overlaps(first: var, second: var): bool {
        return first.x < second.right && first.right > second.x && first.y < second.bottom && first.bottom > second.y;
    }

    function fail(message: string): void {
        harness.failures++;
        console.error(`FAIL [${harness.currentCase.name}] ${message}`);
    }

    function requireNode(node: var, label: string): bool {
        if (node)
            return true;
        harness.fail(`${label} exists`);
        return false;
    }

    function checkInside(node: var, label: string): void {
        if (!harness.requireNode(node, label))
            return;

        const rect = harness.rectInRoot(node);
        if (rect.x < -0.5 || rect.y < -0.5 || rect.right > harness.item.width + 0.5 || rect.bottom > harness.item.height + 0.5)
            harness.fail(`${label} stays inside the tab (${JSON.stringify(rect)})`);
    }

    function checkCase(): void {
        const current = harness.currentCase;
        const tab = harness.item;
        const widget = harness.findByName(tab, "translatorWidget");
        if (!harness.requireNode(widget, "translatorWidget"))
            return harness.next();

        const layout = harness.findByName(tab, "translatorLayout");
        const languageRow = harness.findByName(tab, "languageRow");
        const sourcePanel = harness.findByName(tab, "sourcePanel");
        const resultPanel = harness.findByName(tab, "resultPanel");
        const footer = harness.findByName(tab, "footer");
        const statusLabel = harness.findByName(tab, "statusLabel");
        const fromPicker = harness.findByName(tab, "fromPicker");
        const toPicker = harness.findByName(tab, "toPicker");
        const swapButton = harness.findByName(tab, "swapButton");
        const translateButton = harness.findByName(tab, "translateButton");
        const copyButton = harness.findByName(tab, "copyButton");

        if (tab.compact !== current.compact)
            harness.fail(`tab.pack compact=${tab.compact}, expected ${current.compact}`);
        if (widget.compactLayout !== current.compact)
            harness.fail(`widget.compactLayout=${widget.compactLayout}, expected ${current.compact}`);
        if (tab.minimumWidth > tab.width || tab.minimumHeight > tab.height)
            harness.fail(`tab minimum ${tab.minimumWidth}x${tab.minimumHeight} is larger than its ${tab.width}x${tab.height} case`);

        if (!harness.requireNode(layout, "translatorLayout"))
            return harness.next();
        if (layout.width > tab.width + 0.5 || layout.height > tab.height + 0.5)
            harness.fail(`layout ${layout.width}x${layout.height} is larger than the tab`);
        if (Math.abs(layout.width - widget.contentWidth) > 0.5 || Math.abs(layout.height - widget.contentHeight) > 0.5)
            harness.fail(`layout ${layout.width}x${layout.height} does not use the full padded tab`);

        if (harness.requireNode(sourcePanel, "sourcePanel") && sourcePanel.height + 0.5 < widget.minimumSourceHeight)
            harness.fail(`source height ${sourcePanel.height} is below ${widget.minimumSourceHeight}`);
        if (harness.requireNode(resultPanel, "resultPanel") && resultPanel.height + 0.5 < widget.minimumResultHeight)
            harness.fail(`result height ${resultPanel.height} is below ${widget.minimumResultHeight}`);

        if (sourcePanel && sourcePanel.labelText.length === 0)
            harness.fail("source label is empty");
        if (resultPanel && resultPanel.labelText.length === 0)
            harness.fail("result label is empty");
        if (fromPicker && fromPicker.fieldLabel.length === 0)
            harness.fail("from-language label is empty");
        if (toPicker && toPicker.fieldLabel.length === 0)
            harness.fail("to-language label is empty");
        if (statusLabel && statusLabel.text.length === 0)
            harness.fail("status label is empty");
        if (statusLabel && !statusLabel.visible)
            harness.fail("status label is hidden");

        for (const entry of [
                 ["languageRow", languageRow],
                 ["sourcePanel", sourcePanel],
                 ["resultPanel", resultPanel],
                 ["footer", footer],
                 ["swapButton", swapButton],
                 ["translateButton", translateButton],
                 ["statusLabel", statusLabel]
             ])
            harness.checkInside(entry[1], entry[0]);

        if (fromPicker && fromPicker.width < 80)
            harness.fail(`from picker width ${fromPicker.width} is too small`);
        if (toPicker && toPicker.width < 80)
            harness.fail(`to picker width ${toPicker.width} is too small`);

        if (languageRow && sourcePanel && languageRow.mapToItem(tab, 0, languageRow.height).y > sourcePanel.mapToItem(tab, 0, 0).y + 0.5)
            harness.fail("language row overlaps the source panel");
        if (sourcePanel && resultPanel && sourcePanel.mapToItem(tab, 0, sourcePanel.height).y > resultPanel.mapToItem(tab, 0, 0).y + 0.5)
            harness.fail("source panel overlaps the result panel");
        if (resultPanel && footer && resultPanel.mapToItem(tab, 0, resultPanel.height).y > footer.mapToItem(tab, 0, 0).y + 0.5)
            harness.fail("result panel overlaps the footer");

        if (swapButton && footer && swapButton.mapToItem(tab, 0, swapButton.height).y > footer.mapToItem(tab, 0, 0).y + 0.5)
            harness.fail("swap button collides with the footer actions");
        if (swapButton && translateButton && harness.overlaps(harness.rectInRoot(swapButton), harness.rectInRoot(translateButton)))
            harness.fail("swap and translate buttons overlap");
        if (copyButton && translateButton && copyButton.visible && harness.overlaps(harness.rectInRoot(copyButton), harness.rectInRoot(translateButton)))
            harness.fail("copy and translate buttons overlap");

        const resultScroll = harness.findByName(resultPanel, "panelScroll");
        if (!harness.requireNode(resultScroll, "result scroll view"))
            return harness.next();
        if (!resultScroll.clip)
            harness.fail("result scroll view does not clip its content");
        if (resultScroll.contentHeight <= resultScroll.availableHeight)
            harness.fail(`result text does not scroll (${resultScroll.contentHeight} <= ${resultScroll.availableHeight})`);

        for (const entry of [
                 ["fromPicker", fromPicker],
                 ["toPicker", toPicker],
                 ["swapButton", swapButton],
                 ["translateButton", translateButton]
             ]) {
            if (!entry[1])
                harness.fail(`${entry[0]} exists`);
            else if (!entry[1].activeFocusOnTab)
                harness.fail(`${entry[0]} is not reachable with the keyboard`);
        }

        if (widget && statusLabel && translateButton) {
            widget.setStatus("Network error: could not reach MyMemory.", true);
            if (!widget.statusIsError || !statusLabel.text.includes("Network error"))
                harness.fail("error state is not shown in the footer");
            widget.setStatus("Translating…", false);
            widget.busy = true;
            if (!translateButton.text.includes("Translating"))
                harness.fail("busy state is not shown on the translate button");
            if (translateButton.enabled)
                harness.fail("translate button stays enabled while busy");
            widget.busy = false;
        }

        console.log(`${current.name}: layout ${layout.width}x${layout.height}, source ${sourcePanel.height}, result ${resultPanel.height}, language ${languageRow.height}, footer ${footer.height}`);
        harness.next();
    }

    function next(): void {
        if (harness.item) {
            harness.item.destroy();
            harness.item = null;
        }

        harness.caseIndex++;
        if (harness.caseIndex >= harness.cases.length) {
            console.log(`translator layout checks: ${harness.cases.length} cases, ${harness.failures} failures`);
            Qt.exit(harness.failures === 0 ? 0 : 1);
            return;
        }

        harness.currentCase = harness.cases[harness.caseIndex];
        const component = Qt.createComponent("file://" + harness.tabPath, Component.PreferSynchronous);
        if (component.status !== Component.Ready) {
            harness.fail(`tab loads: ${component.errorString()}`);
            harness.next();
            return;
        }

        const object = component.createObject(harness.contentItem, {
            api: harness.fakeApi(),
            active: false,
            width: harness.currentCase.width,
            height: harness.currentCase.height
        });
        if (!object) {
            harness.fail("tab could be instantiated");
            harness.next();
            return;
        }

        harness.item = object;
        object.x = 0;
        object.y = 0;

        const widget = harness.findByName(object, "translatorWidget");
        if (widget) {
            widget.sourceText = harness.longText.slice(0, 480);
            widget.resultText = harness.longText;
        }

        settle.restart();
    }

    Timer {
        id: settle

        interval: 350
        onTriggered: harness.checkCase()
    }

    Component.onCompleted: {
        if (harness.tabPath.length === 0) {
            console.error("PADILHA_TRANSLATOR_TAB is empty");
            harness.failures++;
            Qt.exit(1);
            return;
        }
        harness.next();
    }
}
