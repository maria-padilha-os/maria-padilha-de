import QtQuick
import QtQuick.Window
import Quickshell

// Loads the calculator tab at its compact minimum and at a full dashboard
// size. The fake backend result path lets the harness exercise the keypad,
// history and errors without starting qalc or touching the network.
Window {
    id: harness

    readonly property string tabPath: Quickshell.env("PADILHA_CALCULATOR_TAB") || ""
    readonly property var palette: ({
            m3surface: "#141218",
            m3surfaceContainer: "#211F26",
            m3surfaceContainerHigh: "#2B2930",
            m3surfaceContainerHighest: "#36343B",
            m3onSurface: "#E6E0E9",
            m3onSurfaceVariant: "#CAC4D0",
            m3outline: "#938F99",
            m3outlineVariant: "#49454F",
            m3primary: "#D0BCFF",
            m3onPrimary: "#381E72",
            m3secondary: "#CCC2DC",
            m3onSecondary: "#332D41",
            m3secondaryContainer: "#4A4458",
            m3onSecondaryContainer: "#E8DEF8",
            m3error: "#F2B8B5"
        })
    readonly property var cases: [
        {
            name: "compact minimum 360x460",
            width: 360,
            height: 460,
            compact: true
        },
        {
            name: "full dashboard 1000x600",
            width: 1000,
            height: 600,
            compact: false
        }
    ]

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

    function collectKeys(object: var, found: var): var {
        if (!object)
            return found;
        if (String(object.objectName || "").indexOf("calculatorKey_") === 0)
            found.push(object);

        const children = object.children || [];
        for (let i = 0; i < children.length; i++)
            harness.collectKeys(children[i], found);
        return found;
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

    function checkInteractions(widget: var): void {
        widget.clear();
        for (const key of ["(", "1", ".", "5", "+", "2", ")"])
            widget.press(key);
        if (widget.expression !== "(1.5+2)")
            harness.fail(`keypad input produced ${JSON.stringify(widget.expression)}`);

        widget.press("backspace");
        if (widget.expression !== "(1.5+2")
            harness.fail(`backspace produced ${JSON.stringify(widget.expression)}`);
        widget.backspace();
        if (widget.expression !== "(1.5+")
            harness.fail(`backspace function produced ${JSON.stringify(widget.expression)}`);

        widget.clear();
        if (widget.expression !== "" || widget.result !== "" || widget.history.length !== 0 || widget.failed)
            harness.fail("clear did not reset the calculator");

        widget.pendingExpression = "6*7";
        widget.completeEvaluation(0, "42\n", "");
        if (widget.result !== "42" || widget.failed || widget.history.length !== 1)
            harness.fail("successful evaluation was not recorded");
        if (widget.history.length > 0 && (widget.history[0].expression !== "6*7" || widget.history[0].result !== "42" || widget.history[0].failed))
            harness.fail("history entry does not match the evaluation");

        widget.pendingExpression = "8/2";
        widget.completeEvaluation(0, " 4 \n", "");
        if (widget.history.length !== 2 || widget.history[0].expression !== "8/2" || widget.history[1].expression !== "6*7")
            harness.fail("history does not keep newest-first entries");

        widget.pendingExpression = "sqrt(";
        widget.completeEvaluation(1, "", "error: malformed expression\n");
        if (!widget.failed || widget.errorText !== "error: malformed expression" || widget.result !== "")
            harness.fail("qalc error text was not preserved");
        if (widget.history.length !== 3 || !widget.history[0].failed)
            harness.fail("failed evaluation is missing from history");

        widget.press("9");
        if (widget.expression !== "9" || widget.failed)
            harness.fail("a digit after a result did not start a fresh expression");

        widget.clear();
        if (widget.history.length !== 0)
            harness.fail("clear did not reset history");
    }

    function checkCase(): void {
        const current = harness.currentCase;
        const tab = harness.item;
        const widget = harness.findByName(tab, "calculatorWidget");
        if (!harness.requireNode(widget, "calculatorWidget"))
            return harness.next();

        const layout = harness.findByName(tab, "calculatorLayout");
        const display = harness.findByName(tab, "calculatorDisplay");
        const history = harness.findByName(tab, "calculatorHistory");
        const keypad = harness.findByName(tab, "calculatorKeypad");
        const input = harness.findByName(tab, "calculatorInput");
        const result = harness.findByName(tab, "calculatorResult");
        const historyList = harness.findByName(tab, "calculatorHistoryList");

        if (!harness.requireNode(layout, "calculatorLayout"))
            return harness.next();
        if (!harness.requireNode(display, "calculatorDisplay"))
            return harness.next();
        if (!harness.requireNode(history, "calculatorHistory"))
            return harness.next();
        if (!harness.requireNode(keypad, "calculatorKeypad"))
            return harness.next();
        if (!harness.requireNode(input, "calculatorInput"))
            return harness.next();
        if (!harness.requireNode(result, "calculatorResult"))
            return harness.next();
        if (!harness.requireNode(historyList, "calculatorHistoryList"))
            return harness.next();

        if (tab.compact !== current.compact)
            harness.fail(`tab.compact=${tab.compact}, expected ${current.compact}`);
        if (widget.compactLayout !== current.compact)
            harness.fail(`widget.compactLayout=${widget.compactLayout}, expected ${current.compact}`);
        if (tab.minimumWidth > tab.width || tab.minimumHeight > tab.height)
            harness.fail(`tab minimum ${tab.minimumWidth}x${tab.minimumHeight} is larger than its ${tab.width}x${tab.height} case`);

        if (layout.width > tab.width + 0.5 || layout.height > tab.height + 0.5)
            harness.fail(`layout ${layout.width}x${layout.height} is larger than the tab`);
        if (Math.abs(layout.width - (tab.width - widget.edgePadding * 2)) > 0.5 || Math.abs(layout.height - (tab.height - widget.edgePadding * 2)) > 0.5)
            harness.fail(`layout ${layout.width}x${layout.height} does not use the padded tab`);

        for (const entry of [
                 ["calculatorDisplay", display],
                 ["calculatorHistory", history],
                 ["calculatorKeypad", keypad],
                 ["calculatorInput", input],
                 ["calculatorResult", result]
             ])
            harness.checkInside(entry[1], entry[0]);

        if (Math.abs(display.width - layout.width) > 0.5)
            harness.fail(`display width ${display.width} does not span the layout ${layout.width}`);
        if (history.height + 0.5 < (current.compact ? 72 : 120))
            harness.fail(`history height ${history.height} is below its minimum`);
        if (keypad.height + 0.5 < widget.compactKeypadHeight)
            harness.fail(`keypad height ${keypad.height} is below ${widget.compactKeypadHeight}`);
        if (history.width < 120 || keypad.width < 120)
            harness.fail(`history/keypad widths are too small (${history.width}, ${keypad.width})`);

        if (current.compact) {
            if (harness.overlaps(harness.rectInRoot(display), harness.rectInRoot(history)))
                harness.fail("display overlaps history in compact layout");
            if (harness.overlaps(harness.rectInRoot(history), harness.rectInRoot(keypad)))
                harness.fail("history overlaps keypad in compact layout");
            if (history.y + history.height > keypad.y + 0.5)
                harness.fail("compact layout does not stack history above the keypad");
        } else {
            if (harness.overlaps(harness.rectInRoot(display), harness.rectInRoot(history)))
                harness.fail("display overlaps history in wide layout");
            if (harness.overlaps(harness.rectInRoot(history), harness.rectInRoot(keypad)))
                harness.fail("history overlaps keypad in wide layout");
            if (history.x >= keypad.x)
                harness.fail("wide layout does not place history beside the keypad");
        }

        if (keypad.columns !== 4)
            harness.fail(`keypad has ${keypad.columns} columns, expected 4`);

        const keys = harness.collectKeys(widget, []);
        if (keys.length !== widget.keys.length)
            harness.fail(`found ${keys.length} key objects, expected ${widget.keys.length}`);
        for (const key of keys) {
            if (key.width + 0.5 < widget.keyMinimumSize || key.height + 0.5 < widget.keyMinimumSize)
                harness.fail(`key ${key.keyValue} is ${key.width}x${key.height}, below the ${widget.keyMinimumSize}px target`);
            if (!key.activeFocusOnTab)
                harness.fail(`key ${key.keyValue} is not reachable with the keyboard`);
            if (!key.accessibleLabel || key.accessibleLabel.length === 0)
                harness.fail(`key ${key.keyValue} has no accessible label`);
            harness.checkInside(key, `key ${key.keyValue}`);
        }

        if (!input.activeFocusOnTab && !input.focus)
            harness.fail("expression input is not keyboard reachable");
        if (!input.Accessible.name || input.Accessible.name.length === 0)
            harness.fail("expression input has no accessible name");

        harness.checkInteractions(widget);

        console.log(`${current.name}: layout ${layout.width}x${layout.height}, display ${display.y} ${display.height}, history ${history.x},${history.y} ${history.width}x${history.height}, keypad ${keypad.x},${keypad.y} ${keypad.width}x${keypad.height}, keys ${keys.length}`);
        harness.next();
    }

    function next(): void {
        if (harness.item) {
            harness.item.destroy();
            harness.item = null;
        }

        harness.caseIndex++;
        if (harness.caseIndex >= harness.cases.length) {
            console.log(`calculator layout checks: ${harness.cases.length} cases, ${harness.failures} failures`);
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
        settle.restart();
    }

    Timer {
        id: settle

        interval: 400
        onTriggered: harness.checkCase()
    }

    Component.onCompleted: {
        if (harness.tabPath.length === 0) {
            console.error("PADILHA_CALCULATOR_TAB is empty");
            harness.failures++;
            Qt.exit(1);
            return;
        }
        harness.next();
    }
}
