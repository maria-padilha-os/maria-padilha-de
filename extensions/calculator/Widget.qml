import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// Front-end for qalc. The host passes the shell API in `api`; every colour
// comes from the live theme so the widget follows palette changes. The same
// item is used as a 360x220 dashboard tab and as a full settings page.
Item {
    id: root

    property var api

    property var history: []
    property string result: ""
    property bool failed: false
    property string pendingExpression: ""

    readonly property var palette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color foreground: root.palette ? root.palette.m3onSurface : "transparent"
    readonly property color muted: root.palette ? root.palette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.palette ? root.palette.m3primary : "transparent"
    readonly property color errorColour: root.palette ? root.palette.m3error : "transparent"
    readonly property color fieldColour: root.palette ? root.palette.m3surfaceContainerHigh : "transparent"
    readonly property color displayColour: root.palette ? root.palette.m3surfaceContainerHighest : "transparent"

    // The tab is 360x220 and a settings page is much taller. Let the display
    // grow a little with the host while keeping the compact tab layout intact.
    readonly property int displayHeight: Math.round(Math.min(72, Math.max(40, root.height * 0.18)))
    readonly property int resultSize: Math.round(Math.min(40, Math.max(24, root.height * 0.11)))

    function evaluate() {
        if (calcProc.running)
            return;
        const expression = input.text.trim();
        if (expression.length === 0)
            return;
        root.pendingExpression = expression;
        calcProc.command = ["qalc", "-t", expression];
        calcProc.running = true;
    }

    function clear() {
        input.text = "";
        root.pendingExpression = "";
        root.history = [];
        root.result = "";
        root.failed = false;
        input.forceActiveFocus();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        spacing: Tokens.spacing.extraSmall

        Rectangle {
            id: inputField

            Layout.fillWidth: true
            Layout.preferredHeight: 30

            radius: Tokens.rounding.medium
            color: root.fieldColour
            border.width: input.activeFocus ? 1 : 0
            border.color: root.accent

            TextInput {
                id: input

                anchors.left: parent.left
                anchors.right: clearAction.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: Tokens.padding.small
                anchors.rightMargin: Tokens.padding.extraSmall

                color: root.foreground
                selectionColor: root.accent
                selectedTextColor: root.palette ? root.palette.m3onPrimary : "transparent"
                font: Tokens.font.body.medium
                verticalAlignment: TextInput.AlignVCenter
                clip: true

                onAccepted: root.evaluate()

                Keys.onEscapePressed: input.text = ""

                Component.onCompleted: input.forceActiveFocus()
            }

            Text {
                anchors.left: parent.left
                anchors.right: clearAction.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.small
                anchors.rightMargin: Tokens.padding.extraSmall
                visible: input.text.length === 0
                text: Tr.tr("Type an expression")
                color: root.muted
                opacity: 0.7
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            MouseArea {
                id: clearAction

                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.extraSmall
                anchors.verticalCenter: parent.verticalCenter
                width: clearLabel.implicitWidth + Tokens.padding.small * 2
                height: parent.height - Tokens.padding.extraSmall * 2

                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: root.clear()

                Text {
                    id: clearLabel

                    anchors.centerIn: parent
                    text: Tr.tr("Clear")
                    color: clearAction.containsMouse || clearAction.pressed ? root.accent : root.muted
                    font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                }
            }
        }

        Rectangle {
            id: display

            Layout.fillWidth: true
            Layout.preferredHeight: root.displayHeight

            radius: Tokens.rounding.large
            color: root.displayColour
            border.width: root.failed ? 1 : 0
            border.color: root.errorColour

            Text {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium

                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: root.result.length > 0 ? root.result : "0"
                color: root.failed ? root.errorColour : root.result.length > 0 ? root.foreground : root.muted
                opacity: root.result.length > 0 ? 1 : 0.5
                elide: Text.ElideRight
                maximumLineCount: 1
                font: Tokens.font.mono.builders.large.size(root.resultSize).weight(Font.DemiBold).build()
            }
        }

        Flickable {
            id: historyFlick

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: Math.max(historyColumn.implicitHeight, height)

            Column {
                id: historyColumn

                width: historyFlick.width
                y: Math.max(0, (historyFlick.height - implicitHeight) / 2)

                Repeater {
                    model: root.history

                    delegate: Item {
                        id: historyRow

                        required property var modelData

                        width: historyColumn.width
                        height: Math.max(expressionText.implicitHeight, valueText.implicitHeight) + Math.ceil(Tokens.spacing.extraSmall / 2)

                        Text {
                            id: expressionText

                            anchors.left: parent.left
                            anchors.right: valueText.left
                            anchors.rightMargin: Tokens.spacing.small
                            anchors.verticalCenter: parent.verticalCenter
                            text: historyRow.modelData.expression + " ="
                            color: root.muted
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        Text {
                            id: valueText

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width * 0.55)
                            horizontalAlignment: Text.AlignRight
                            text: historyRow.modelData.result
                            color: historyRow.modelData.failed ? root.errorColour : root.accent
                            font: Tokens.font.mono.small
                            elide: Text.ElideLeft
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.history.length === 0
                text: Tr.tr("Results appear here")
                color: root.muted
                opacity: 0.6
                font: Tokens.font.body.small
            }
        }
    }

    Process {
        id: calcProc

        stdout: StdioCollector {
            id: stdoutCollector
        }

        stderr: StdioCollector {
            id: stderrCollector
        }

        onExited: (code) => { // qmllint disable signal-handler-parameters
            const stdout = stdoutCollector.text.trim();
            const stderr = stderrCollector.text.trim();
            const success = code === 0 && stdout.length > 0;
            const value = success ? stdout : stderr.length > 0 ? stderr : Tr.tr("Error");

            if (root.pendingExpression.length > 0) {
                root.result = value;
                root.failed = !success;

                root.history = [
                    {
                        expression: root.pendingExpression,
                        result: value,
                        failed: !success
                    }
                ].concat(root.history).slice(0, 8);
                root.pendingExpression = "";
            }
        }
    }
}
