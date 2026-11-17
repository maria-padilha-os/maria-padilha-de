pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// Graphical front-end for qalc. The host passes the shell API in `api`; every
// colour comes from the live theme so the widget follows palette changes.
// Expressions still go to the same qalc CLI as before, as one argument in a
// command array, so qalc owns parsing, formatting and error messages and no
// user input is ever handed to a shell.
Item {
    id: root

    property var api
    property bool compact: false
    property bool active: true

    property var history: []
    property string result: ""
    property string errorText: ""
    property bool failed: false
    property string pendingExpression: ""
    property bool justEvaluated: false
    readonly property bool busy: calcProc.running

    property alias expression: input.text

    // The tab mirrors these so the dashboard clamps the panel before it is
    // created. The height leaves room for five rows of ≥44 px touch targets,
    // the display and a visible history.
    readonly property int minimumWidth: 360
    readonly property int minimumHeight: 460

    readonly property bool compactLayout: root.compact || root.width < 680 || root.height < 500
    readonly property int edgePadding: root.compactLayout ? Tokens.padding.medium : Tokens.padding.large
    readonly property int sectionSpacing: root.compactLayout ? Tokens.spacing.small : Tokens.spacing.medium
    readonly property int keySpacing: root.compactLayout ? Tokens.spacing.extraSmall : Tokens.spacing.small
    readonly property int keyMinimumSize: 44
    readonly property int compactKeypadHeight: 5 * root.keyMinimumSize + 4 * root.keySpacing
    readonly property int historyLimit: 20

    readonly property var themePalette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color foreground: root.themePalette ? root.themePalette.m3onSurface : "transparent"
    readonly property color muted: root.themePalette ? root.themePalette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.themePalette ? root.themePalette.m3primary : "transparent"
    readonly property color onAccent: root.themePalette ? root.themePalette.m3onPrimary : "transparent"
    readonly property color errorColour: root.themePalette ? root.themePalette.m3error : "transparent"
    readonly property color displayColour: root.themePalette ? root.themePalette.m3surfaceContainerHighest : "transparent"
    readonly property color surfaceColour: root.themePalette ? root.themePalette.m3surfaceContainerHigh : "transparent"
    readonly property color keyColour: root.themePalette ? root.themePalette.m3surfaceContainerHigh : "transparent"
    readonly property color utilityColour: root.themePalette ? root.themePalette.m3surfaceContainer : "transparent"
    readonly property color operatorColour: root.themePalette ? root.themePalette.m3secondaryContainer : "transparent"
    readonly property color onOperator: root.themePalette ? root.themePalette.m3onSecondaryContainer : "transparent"
    readonly property color outline: root.themePalette ? root.themePalette.m3outline : "transparent"
    readonly property color outlineVariant: root.themePalette ? root.themePalette.m3outlineVariant : "transparent"

    implicitWidth: 420
    implicitHeight: 560

    // Kept in calculator order. Operators insert qalc syntax (not the Unicode
    // label) so parsing stays exactly the same as typing in a terminal.
    readonly property var keys: [
        {
            "value": "clear",
            "label": "C",
            "accessibleName": Tr.tr("Clear"),
            "kind": "utility"
        },
        {
            "value": "(",
            "label": "(",
            "accessibleName": Tr.tr("Open parenthesis"),
            "kind": "utility"
        },
        {
            "value": ")",
            "label": ")",
            "accessibleName": Tr.tr("Close parenthesis"),
            "kind": "utility"
        },
        {
            "value": "/",
            "label": "÷",
            "accessibleName": Tr.tr("Divide"),
            "kind": "operator"
        },
        {
            "value": "7",
            "label": "7",
            "accessibleName": "7",
            "kind": "digit"
        },
        {
            "value": "8",
            "label": "8",
            "accessibleName": "8",
            "kind": "digit"
        },
        {
            "value": "9",
            "label": "9",
            "accessibleName": "9",
            "kind": "digit"
        },
        {
            "value": "*",
            "label": "×",
            "accessibleName": Tr.tr("Multiply"),
            "kind": "operator"
        },
        {
            "value": "4",
            "label": "4",
            "accessibleName": "4",
            "kind": "digit"
        },
        {
            "value": "5",
            "label": "5",
            "accessibleName": "5",
            "kind": "digit"
        },
        {
            "value": "6",
            "label": "6",
            "accessibleName": "6",
            "kind": "digit"
        },
        {
            "value": "-",
            "label": "−",
            "accessibleName": Tr.tr("Subtract"),
            "kind": "operator"
        },
        {
            "value": "1",
            "label": "1",
            "accessibleName": "1",
            "kind": "digit"
        },
        {
            "value": "2",
            "label": "2",
            "accessibleName": "2",
            "kind": "digit"
        },
        {
            "value": "3",
            "label": "3",
            "accessibleName": "3",
            "kind": "digit"
        },
        {
            "value": "+",
            "label": "+",
            "accessibleName": Tr.tr("Add"),
            "kind": "operator"
        },
        {
            "value": "0",
            "label": "0",
            "accessibleName": "0",
            "kind": "digit"
        },
        {
            "value": ".",
            "label": ".",
            "accessibleName": Tr.tr("Decimal point"),
            "kind": "digit"
        },
        {
            "value": "backspace",
            "label": "⌫",
            "accessibleName": Tr.tr("Backspace"),
            "kind": "utility"
        },
        {
            "value": "equals",
            "label": "=",
            "accessibleName": Tr.tr("Equals"),
            "kind": "equals"
        }
    ]

    // Turns qalc syntax into rich text: sqrt -> root, ^ -> superscript,
    // simple numeric fractions -> superscript/fraction slash/subscript,
    // single-letter variables -> italic, plus the usual operator glyphs.
    function pretty(source: string): string {
        if (!source)
            return "";

        let text = source.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        text = text.replace(/\b([a-zA-Z])\b/g, "<i>$1</i>");
        text = text.replace(/\bpi\b/g, "π");
        text = text.replace(/sqrt\(([^()]*)\)/g, "√($1)");
        text = text.replace(/\^\(([^()]*)\)/g, "<sup>$1</sup>");
        text = text.replace(/\^(-?\w+)/g, "<sup>$1</sup>");
        text = text.replace(/(\d+(?:\.\d+)?)\s*\/\s*(\d+(?:\.\d+)?)/g, "<sup>$1</sup>⁄<sub>$2</sub>");
        text = text.replace(/!=/g, "≠").replace(/>=/g, "≥").replace(/<=/g, "≤");
        text = text.replace(/\*/g, " · ");
        text = text.replace(/-/g, "−");
        return text;
    }

    function focusInput(): void {
        if (root.active)
            input.forceActiveFocus();
    }

    function insert(value: string): void {
        if (!value)
            return;

        // A digit or operator after a result starts a fresh expression instead
        // of editing the expression that produced the result.
        if (root.justEvaluated) {
            input.text = "";
            root.result = "";
            root.errorText = "";
            root.failed = false;
            root.justEvaluated = false;
        }

        const cursor = input.cursorPosition >= 0 ? input.cursorPosition : input.text.length;
        const selectionStart = input.selectionStart >= 0 ? input.selectionStart : cursor;
        const selectionEnd = input.selectionEnd >= 0 ? input.selectionEnd : cursor;
        const hasSelection = selectionStart !== selectionEnd;
        const start = hasSelection ? Math.min(selectionStart, selectionEnd) : cursor;
        const end = hasSelection ? Math.max(selectionStart, selectionEnd) : cursor;

        input.text = input.text.slice(0, start) + value + input.text.slice(end);
        input.cursorPosition = start + value.length;
        root.focusInput();
    }

    function backspace(): void {
        if (root.justEvaluated) {
            root.result = "";
            root.errorText = "";
            root.failed = false;
            root.justEvaluated = false;
        }

        const cursor = input.cursorPosition >= 0 ? input.cursorPosition : input.text.length;
        const selectionStart = input.selectionStart >= 0 ? input.selectionStart : cursor;
        const selectionEnd = input.selectionEnd >= 0 ? input.selectionEnd : cursor;
        const hasSelection = selectionStart !== selectionEnd;
        const start = hasSelection ? Math.min(selectionStart, selectionEnd) : Math.max(0, cursor - 1);
        const end = hasSelection ? Math.max(selectionStart, selectionEnd) : cursor;

        input.text = input.text.slice(0, start) + input.text.slice(end);
        input.cursorPosition = start;
        root.focusInput();
    }

    function clear(): void {
        if (calcProc.running)
            calcProc.running = false;

        root.pendingExpression = "";
        input.text = "";
        root.history = [];
        root.result = "";
        root.errorText = "";
        root.failed = false;
        root.justEvaluated = false;
        root.focusInput();
    }

    function press(key: string): void {
        if (key === "clear" || key === "C") {
            root.clear();
        } else if (key === "backspace" || key === "⌫") {
            root.backspace();
        } else if (key === "equals" || key === "=") {
            root.evaluate();
        } else {
            root.insert(key);
        }
    }

    function evaluate(): void {
        if (calcProc.running)
            return;

        const expression = input.text.trim();
        if (expression.length === 0) {
            root.focusInput();
            return;
        }

        root.pendingExpression = expression;
        root.errorText = "";
        root.failed = false;
        // One argv element, no shell: qalc receives the expression verbatim.
        calcProc.command = ["qalc", "-t", expression];
        calcProc.running = true;
        root.focusInput();
    }

    function prependHistory(entry: var): void {
        root.history = [entry].concat(root.history).slice(0, root.historyLimit);
    }

    // Shared by the Process handler and the offscreen tests. Keeping the
    // success/error mapping here means both paths preserve qalc's exact text.
    function completeEvaluation(exitCode: int, standardOutput: string, standardError: string): void {
        const expression = root.pendingExpression;
        if (expression.length === 0)
            return;

        root.pendingExpression = "";

        const output = (standardOutput || "").trim();
        const error = (standardError || "").trim();

        if (exitCode === 0 && output.length > 0) {
            root.result = output;
            root.errorText = "";
            root.failed = false;
            root.justEvaluated = true;
            root.prependHistory({
                "expression": expression,
                "result": output,
                "failed": false
            });
        } else {
            const message = error.length > 0 ? error : output.length > 0 ? output : Tr.tr("Invalid expression");
            root.result = "";
            root.errorText = message;
            root.failed = true;
            root.justEvaluated = true;
            root.prependHistory({
                "expression": expression,
                "result": message,
                "failed": true
            });
        }

        root.focusInput();
    }

    Component.onCompleted: root.focusInput()
    onActiveChanged: {
        if (root.active)
            root.focusInput();
    }

    component CalculatorKey: Rectangle {
        id: key
        objectName: "calculatorKey_" + key.keyValue

        required property var modelData

        readonly property string keyValue: key.modelData.value
        readonly property string accessibleLabel: key.modelData.accessibleName || key.modelData.label
        readonly property bool hovered: keyMouse.containsMouse
        readonly property bool pressed: keyMouse.pressed
        readonly property bool primary: key.modelData.kind === "equals"
        readonly property bool operator: key.modelData.kind === "operator"
        readonly property bool utility: key.modelData.kind === "utility"
        readonly property color buttonColour: key.primary ? root.accent : key.operator ? root.operatorColour : key.utility ? root.utilityColour : root.keyColour
        readonly property color labelColour: key.primary ? root.onAccent : key.operator ? root.onOperator : root.foreground

        signal activated()

        function activate(): void {
            key.activated();
            root.press(key.keyValue);
        }

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: root.keyMinimumSize
        Layout.minimumHeight: root.keyMinimumSize
        implicitWidth: Math.max(keyLabel.implicitWidth + Tokens.padding.large * 2, root.keyMinimumSize)
        implicitHeight: Math.max(keyLabel.implicitHeight + Tokens.padding.small * 2, root.keyMinimumSize)

        radius: Tokens.rounding.medium
        color: key.pressed ? Qt.tint(key.buttonColour, Qt.alpha(root.foreground, 0.18)) : key.hovered ? Qt.tint(key.buttonColour, Qt.alpha(root.foreground, 0.10)) : key.buttonColour
        border.width: key.activeFocus ? 2 : key.primary ? 0 : 1
        border.color: key.activeFocus ? (key.primary ? root.onAccent : root.accent) : root.outlineVariant
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: key.accessibleLabel
        Accessible.description: key.primary ? Tr.tr("Evaluate the expression") : key.modelData.kind === "operator" ? Tr.tr("Insert this operator") : Tr.tr("Insert this value")

        Keys.onReturnPressed: key.activate()
        Keys.onSpacePressed: key.activate()

        Text {
            id: keyLabel

            anchors.centerIn: parent
            text: key.modelData.label
            color: key.labelColour
            font: key.primary ? Tokens.font.headline.medium : key.operator ? Tokens.font.title.medium : Tokens.font.title.large
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: keyMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                key.forceActiveFocus();
                key.activate();
            }
        }
    }

    GridLayout {
        id: layout
        objectName: "calculatorLayout"

        anchors.fill: parent
        anchors.margins: root.edgePadding
        columns: root.compactLayout ? 1 : 2
        rowSpacing: root.sectionSpacing
        columnSpacing: root.sectionSpacing

        Rectangle {
            id: display
            objectName: "calculatorDisplay"

            Layout.row: 0
            Layout.column: 0
            Layout.columnSpan: root.compactLayout ? 1 : 2
            Layout.fillWidth: true
            Layout.minimumHeight: root.compactLayout ? 78 : 104
            Layout.preferredHeight: root.compactLayout ? 88 : 112
            radius: Tokens.rounding.large
            color: root.displayColour
            border.width: input.activeFocus ? 2 : 1
            border.color: input.activeFocus ? root.accent : root.outlineVariant
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: 0

                Item {
                    id: expressionField

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(input.implicitHeight, root.compactLayout ? 30 : 38)

                    TextInput {
                        id: input
                        objectName: "calculatorInput"

                        anchors.fill: parent
                        horizontalAlignment: TextInput.AlignRight
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.foreground
                        selectionColor: root.accent
                        selectedTextColor: root.onAccent
                        font: root.compactLayout ? Tokens.font.title.medium : Tokens.font.headline.small
                        clip: true
                        focus: true
                        activeFocusOnTab: true
                        selectByMouse: true

                        Accessible.role: Accessible.EditableText
                        Accessible.name: Tr.tr("Calculation")

                        onAccepted: root.evaluate()
                        Keys.onEscapePressed: root.clear()
                    }

                    Text {
                        anchors.fill: parent
                        visible: input.text.length === 0
                        text: "0"
                        color: root.muted
                        opacity: 0.7
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        font: input.font
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: resultText
                    objectName: "calculatorResult"

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: root.busy ? Tr.tr("Evaluating…") : root.failed ? root.errorText : root.result.length > 0 ? root.pretty(root.result) : ""
                    textFormat: root.failed || root.busy ? Text.PlainText : Text.RichText
                    color: root.failed ? root.errorColour : root.busy ? root.muted : root.result.length > 0 ? root.foreground : root.muted
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignBottom
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font: (root.compactLayout ? Tokens.font.title.builders.large.weight(Font.DemiBold) : Tokens.font.headline.builders.large.scale(1.2).weight(Font.DemiBold)).build()

                    Accessible.role: Accessible.StaticText
                    Accessible.name: root.failed ? root.errorText : root.result
                }
            }
        }

        Rectangle {
            id: historyPanel
            objectName: "calculatorHistory"

            Layout.row: 1
            Layout.column: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: root.compactLayout ? 0 : 260
            Layout.preferredWidth: root.compactLayout ? -1 : Math.max(320, root.width * 0.45)
            Layout.minimumHeight: root.compactLayout ? 72 : 120
            radius: Tokens.rounding.large
            color: root.surfaceColour
            border.width: 1
            border.color: root.outlineVariant
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.extraSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Text {
                        text: Tr.tr("History")
                        color: root.foreground
                        font: Tokens.font.label.medium
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.history.length > 0 ? String(root.history.length) : ""
                        color: root.muted
                        font: Tokens.font.label.small
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: historyList
                        objectName: "calculatorHistoryList"

                        anchors.fill: parent
                        model: root.history
                        spacing: Tokens.spacing.extraSmall
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        visible: root.history.length > 0

                        delegate: Item {
                            id: historyEntry
                            objectName: "calculatorHistoryEntry"

                            required property var modelData

                            width: historyList.width
                            height: entryColumn.implicitHeight + Tokens.padding.extraSmall * 2

                            ColumnLayout {
                                id: entryColumn

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: root.pretty(historyEntry.modelData.expression) + " ="
                                    textFormat: Text.RichText
                                    color: root.muted
                                    horizontalAlignment: Text.AlignRight
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: historyEntry.modelData.failed ? historyEntry.modelData.result : root.pretty(historyEntry.modelData.result)
                                    textFormat: historyEntry.modelData.failed ? Text.PlainText : Text.RichText
                                    color: historyEntry.modelData.failed ? root.errorColour : root.accent
                                    horizontalAlignment: Text.AlignRight
                                    font: Tokens.font.body.medium
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.history.length === 0
                        text: Tr.tr("Your calculations will appear here")
                        color: root.muted
                        opacity: 0.7
                        font: Tokens.font.body.small
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        width: parent.width
                    }
                }
            }
        }

        GridLayout {
            id: keypad
            objectName: "calculatorKeypad"

            Layout.row: root.compactLayout ? 2 : 1
            Layout.column: root.compactLayout ? 0 : 1
            Layout.fillWidth: true
            Layout.fillHeight: !root.compactLayout
            Layout.minimumWidth: root.compactLayout ? 0 : root.keyMinimumSize * 4 + root.keySpacing * 3
            Layout.preferredWidth: root.compactLayout ? -1 : Math.min(440, Math.max(320, root.width * 0.42))
            Layout.minimumHeight: root.compactKeypadHeight
            Layout.preferredHeight: root.compactKeypadHeight
            columns: 4
            rowSpacing: root.keySpacing
            columnSpacing: root.keySpacing

            Repeater {
                model: root.keys

                delegate: CalculatorKey {}
            }
        }
    }

    Process {
        id: calcProc

        stdout: StdioCollector {
            id: calcOut
        }
        stderr: StdioCollector {
            id: calcErr
        }

        onExited: (exitCode) => {
            root.completeEvaluation(exitCode, calcOut.text, calcErr.text);
        }
    }
}
