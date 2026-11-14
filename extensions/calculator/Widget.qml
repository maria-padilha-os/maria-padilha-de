import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// Front-end for qalc with a light math renderer: the current expression and
// the result are typeset (fractions, exponents, roots, italics) with rich
// text. The host passes the shell API in `api`.
Item {
    id: root

    property var api

    property var history: []
    property string result: ""
    property string errorText: ""
    property bool failed: false
    property string pendingExpression: ""
    readonly property bool busy: calcProc.running

    readonly property var themePalette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color foreground: root.themePalette ? root.themePalette.m3onSurface : "transparent"
    readonly property color muted: root.themePalette ? root.themePalette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.themePalette ? root.themePalette.m3primary : "transparent"
    readonly property color onAccent: root.themePalette ? root.themePalette.m3onPrimary : "transparent"
    readonly property color errorColour: root.themePalette ? root.themePalette.m3error : "transparent"
    readonly property color fieldColour: root.themePalette ? root.themePalette.m3surfaceContainerHigh : "transparent"
    readonly property color outline: root.themePalette ? root.themePalette.m3outlineVariant : "transparent"

    // Minimum readable size. Tab.qml mirrors these so the dashboard can clamp
    // the panel before the widget is created.
    readonly property int minimumWidth: 300
    readonly property int minimumHeight: 180

    readonly property bool compact: root.height < Tokens.sizes.dashboard.mediaTabHeight
    readonly property int edgePadding: root.compact ? Tokens.padding.medium : Tokens.padding.large
    readonly property real contentWidth: Math.min(Math.max(root.minimumWidth, root.width - root.edgePadding * 2), 720)

    implicitWidth: 360
    implicitHeight: 220

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

    function evaluate(): void {
        if (calcProc.running)
            return;

        const expression = input.text.trim();
        if (expression.length === 0)
            return;

        root.pendingExpression = expression;
        calcProc.command = ["qalc", "-t", expression];
        calcProc.running = true;
    }

    function run(expression: string): void {
        input.text = expression;
        root.evaluate();
    }

    function clear(): void {
        input.text = "";
        root.pendingExpression = "";
        root.history = [];
        root.result = "";
        root.errorText = "";
        root.failed = false;
        input.forceActiveFocus();
    }

    component ActionButton: Rectangle {
        id: button

        property string label
        property string accessibleName
        property bool primary
        signal clicked()

        readonly property bool hovered: buttonMouse.containsMouse
        readonly property bool pressed: buttonMouse.pressed

        implicitWidth: Math.max(buttonLabel.implicitWidth + Tokens.padding.large * 2, Tokens.padding.extraExtraLarge)
        implicitHeight: Math.max(buttonLabel.implicitHeight + Tokens.padding.small * 2, Tokens.sizes.bar.innerWidth)
        radius: Tokens.rounding.small
        color: button.primary ? (button.pressed ? Qt.alpha(root.accent, 0.82) : root.accent) : button.hovered ? Qt.alpha(root.muted, 0.12) : "transparent"
        border.width: button.primary ? 0 : button.activeFocus ? 2 : 1
        border.color: button.activeFocus ? root.accent : root.outline
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: button.accessibleName || button.label

        Keys.onReturnPressed: button.clicked()
        Keys.onSpacePressed: button.clicked()

        Text {
            id: buttonLabel

            anchors.centerIn: parent
            text: button.label
            color: button.primary ? root.onAccent : button.activeFocus ? root.accent : root.muted
            font: Tokens.font.label.medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                button.forceActiveFocus();
                button.clicked();
            }
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.contentWidth
        spacing: root.compact ? Tokens.spacing.extraSmall : Tokens.spacing.small

        Text {
            Layout.fillWidth: true
            Layout.topMargin: root.compact ? 0 : Tokens.spacing.medium
            visible: input.text.length > 0
            text: root.pretty(input.text)
            textFormat: Text.RichText
            color: root.muted
            horizontalAlignment: Text.AlignHCenter
            font: root.compact ? Tokens.font.title.large : Tokens.font.headline.small
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.busy || root.failed || root.result.length > 0
            text: root.busy ? Tr.tr("Evaluating…") : root.failed ? root.errorText : root.pretty(root.result)
            textFormat: root.failed || root.busy ? Text.PlainText : Text.RichText
            color: root.failed ? root.errorColour : root.busy ? root.muted : root.foreground
            horizontalAlignment: Text.AlignHCenter
            font: (root.compact ? Tokens.font.headline.medium : Tokens.font.headline.builders.large.scale(1.4).build()).weight(Font.DemiBold)
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.history.length === 0 && root.result.length === 0 && !root.failed && !root.busy && input.text.length === 0

            Column {
                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "π"
                    color: root.accent
                    opacity: 0.7
                    font: Tokens.font.headline.builders.large.scale(1.4).build()
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.tr("Type a calculation")
                    color: root.muted
                    font: Tokens.font.body.medium
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.history.length > 0
            clip: true
            contentHeight: historyColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: historyColumn

                width: parent.width
                spacing: Tokens.spacing.extraSmall / 2

                Repeater {
                    model: root.history

                    delegate: Text {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.pretty(modelData.expression) + " = " + root.pretty(modelData.result)
                        textFormat: Text.RichText
                        color: root.muted
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }

        Rectangle {
            id: inputField

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(input.implicitHeight, buttonRow.implicitHeight) + Tokens.padding.medium * 2
            radius: Tokens.rounding.medium
            color: root.fieldColour
            border.width: input.activeFocus ? 2 : 1
            border.color: input.activeFocus ? root.accent : "transparent"

            TextInput {
                id: input

                anchors.left: parent.left
                anchors.leftMargin: Tokens.padding.medium
                anchors.right: buttonRow.left
                anchors.rightMargin: Tokens.padding.small
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                verticalAlignment: TextInput.AlignVCenter
                color: root.foreground
                selectionColor: root.accent
                selectedTextColor: root.onAccent
                font: root.compact ? Tokens.font.body.medium : Tokens.font.body.large
                clip: true
                focus: true

                Accessible.role: Accessible.EditableText
                Accessible.name: Tr.tr("Calculation")

                onAccepted: root.evaluate()
                Keys.onEscapePressed: root.clear()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
                    text: Tr.tr("2 + 2, sqrt(2), 10/3")
                    color: root.muted
                    font: input.font
                    elide: Text.ElideRight
                    width: Math.max(0, parent.width)
                }
            }

            Row {
                id: buttonRow

                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.small
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.extraSmall

                ActionButton {
                    label: "="
                    accessibleName: Tr.tr("Evaluate")
                    primary: true
                    onClicked: root.evaluate()
                }

                ActionButton {
                    label: "×"
                    accessibleName: Tr.tr("Clear")
                    onClicked: root.clear()
                }
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
            const output = calcOut.text.trim();
            if (exitCode === 0 && output.length > 0) {
                root.result = output;
                root.errorText = "";
                root.failed = false;
                root.history = [{ expression: root.pendingExpression, result: output }].concat(root.history).slice(0, 8);
            } else {
                root.result = "";
                root.failed = true;
                root.errorText = calcErr.text.trim() || output || Tr.tr("Invalid expression");
            }
        }
    }
}
