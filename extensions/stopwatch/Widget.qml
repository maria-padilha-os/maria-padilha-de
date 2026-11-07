import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n

Item {
    id: root

    property var api
    property bool compact: false

    property bool running: false
    property real elapsed: 0
    property real anchorTime: 0
    property var laps: []

    readonly property var palette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color fg: root.palette ? root.palette.m3onSurface : "transparent"
    readonly property color muted: root.palette ? root.palette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.palette ? root.palette.m3primary : "transparent"

    function formatTime(ms: real) {
        const total = Math.max(0, Math.floor(ms / 10));
        const centis = total % 100;
        const seconds = Math.floor(total / 100) % 60;
        const minutes = Math.floor(total / 6000);
        return `${minutes}:${String(seconds).padStart(2, "0")}.${String(centis).padStart(2, "0")}`;
    }

    function start() {
        if (running)
            return;
        anchorTime = Date.now() - elapsed;
        running = true;
    }

    function stop() {
        if (!running)
            return;
        elapsed = Date.now() - anchorTime;
        running = false;
    }

    function reset() {
        running = false;
        elapsed = 0;
        laps = [];
    }

    function lap() {
        if (elapsed > 0)
            laps = [elapsed].concat(laps).slice(0, 4);
    }

    Timer {
        interval: 50
        repeat: true
        running: root.running
        onTriggered: root.elapsed = Date.now() - root.anchorTime
    }

    component ActionButton: Rectangle {
        id: button

        property string label
        signal clicked()

        implicitWidth: 92
        implicitHeight: 34
        radius: Tokens.rounding.full
        color: buttonMouse.pressed ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : "transparent"
        border.width: 1
        border.color: root.muted

        Text {
            anchors.centerIn: parent
            text: button.label
            color: root.fg
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - (root.compact ? Tokens.padding.medium : Tokens.padding.large) * 2, 460)
        height: Math.min(parent.height - (root.compact ? Tokens.padding.medium : Tokens.padding.large) * 2, 420)
        spacing: Tokens.spacing.small

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: root.laps.length === 0

            Text {
                anchors.centerIn: parent
                text: root.formatTime(root.elapsed)
                color: root.fg
                font.pixelSize: root.compact ? 34 : 44
                font.family: "monospace"
                font.weight: Font.DemiBold
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.extraSmall

            ActionButton {
                label: root.running ? Tr.tr("Stop") : Tr.tr("Start")
                onClicked: root.running ? root.stop() : root.start()
            }

            ActionButton {
                label: Tr.tr("Lap")
                onClicked: root.lap()
            }

            ActionButton {
                label: Tr.tr("Reset")
                onClicked: root.reset()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            spacing: 2

            Repeater {
                model: root.laps

                delegate: Text {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Tr.tr("Lap %1").arg(root.laps.length - index) + "   " + root.formatTime(modelData)
                    color: root.muted
                    font.pixelSize: 12
                    font.family: "monospace"
                }
            }
        }
    }
}
