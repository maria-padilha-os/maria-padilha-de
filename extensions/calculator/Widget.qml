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

    readonly property var palette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color foreground: root.palette ? root.palette.m3onSurface : "transparent"
    readonly property color muted: root.palette ? root.palette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.palette ? root.palette.m3primary : "transparent"
    readonly property color onAccent: root.palette ? root.palette.m3onPrimary : "transparent"
    readonly property color errorColour: root.palette ? root.palette.m3error : "transparent"
    readonly property color fieldColour: root.palette ? root.palette.m3surfaceContainerHigh : "transparent"

    readonly property bool compact: root.height < 320
    readonly property real contentWidth: Math.min(Math.max(300, root.width - Tokens.padding.large * 2), 720)

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
        property bool primary
        signal clicked()

        width: root.compact ? 30 : 40
        height: root.compact ? 24 : 32
        radius: Tokens.rounding.small
        color: button.primary ? root.accent : "transparent"
        border.width: button.primary ? 0 : 1
        border.color: root.muted

        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.primary ? root.onAccent : root.muted
            font.pixelSize: button.height * 0.5
            font.weight: Font.Medium
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
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
            font.pixelSize: root.compact ? 22 : 36
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.failed || root.result.length > 0
            text: root.failed ? root.errorText : root.pretty(root.result)
            textFormat: root.failed ? Text.PlainText : Text.RichText
            color: root.failed ? root.errorColour : root.foreground
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: root.compact ? 30 : 52
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
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
                spacing: 2

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
                        font.pixelSize: root.compact ? 11 : 14
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.compact ? 34 : 48
            radius: Tokens.rounding.medium
            color: root.fieldColour
            border.width: input.activeFocus ? 1 : 0
            border.color: root.accent

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: root.compact ? 76 : 100
                verticalAlignment: TextInput.AlignVCenter
                color: root.foreground
                selectionColor: root.accent
                selectedTextColor: root.onAccent
                font.pixelSize: root.compact ? 15 : 19
                clip: true
                focus: true

                onAccepted: root.evaluate()
                Keys.onEscapePressed: root.clear()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
                    text: Tr.tr("2 + 2, sqrt(2), 10/3")
                    color: root.muted
                    font: input.font
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                ActionButton {
                    label: "="
                    primary: true
                    onClicked: root.evaluate()
                }

                ActionButton {
                    label: "×"
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
