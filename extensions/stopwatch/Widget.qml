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

    readonly property var themePalette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color fg: root.themePalette ? root.themePalette.m3onSurface : "transparent"
    readonly property color muted: root.themePalette ? root.themePalette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.themePalette ? root.themePalette.m3primary : "transparent"
    readonly property color onAccent: root.themePalette ? root.themePalette.m3onPrimary : "transparent"
    readonly property color outline: root.themePalette ? root.themePalette.m3outlineVariant : "transparent"

    readonly property int minimumWidth: 300
    readonly property int minimumHeight: 200
    readonly property int edgePadding: root.compact ? Tokens.padding.medium : Tokens.padding.large
    readonly property real contentWidth: Math.min(Math.max(root.minimumWidth, root.width - root.edgePadding * 2), 460)

    implicitWidth: 340
    implicitHeight: 230

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
        property bool primary
        signal clicked()

        readonly property bool hovered: buttonMouse.containsMouse
        readonly property bool pressed: buttonMouse.pressed

        Layout.fillWidth: true
        Layout.minimumWidth: implicitWidth
        implicitWidth: Math.max(buttonLabel.implicitWidth + Tokens.padding.large * 2, Tokens.padding.extraExtraLarge + Tokens.padding.small)
        implicitHeight: Math.max(buttonLabel.implicitHeight + Tokens.padding.small * 2, Tokens.sizes.bar.innerWidth)
        radius: Tokens.rounding.full
        color: !button.enabled ? "transparent" : button.primary ? (button.pressed ? Qt.alpha(root.accent, 0.82) : root.accent) : button.hovered ? Qt.alpha(root.accent, 0.18) : "transparent"
        border.width: button.primary ? 0 : button.activeFocus ? 2 : 1
        border.color: button.activeFocus ? root.accent : root.outline
        opacity: button.enabled ? 1 : 0.45
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: button.label

        Keys.onReturnPressed: button.clicked()
        Keys.onSpacePressed: button.clicked()

        Text {
            id: buttonLabel

            anchors.centerIn: parent
            text: button.label
            color: button.primary ? root.onAccent : button.activeFocus ? root.accent : root.fg
            font: Tokens.font.label.medium
            elide: Text.ElideRight
            width: Math.max(0, parent.width - Tokens.padding.small * 2)
            horizontalAlignment: Text.AlignHCenter
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                button.forceActiveFocus();
                button.clicked();
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: root.contentWidth
        height: Math.min(parent.height - root.edgePadding * 2, 420)
        spacing: Tokens.spacing.small

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: root.laps.length === 0
            spacing: Tokens.spacing.extraSmall

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: timeLabel.implicitHeight

                Text {
                    id: timeLabel

                    anchors.centerIn: parent
                    text: root.formatTime(root.elapsed)
                    color: root.running ? root.accent : root.fg
                    font: Tokens.font.mono.builders.large.scale(root.compact ? 2.1 : 2.75).weight(Font.DemiBold).build()
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.laps.length === 0 && !root.running && root.elapsed === 0
                text: Tr.tr("Press Start to begin")
                color: root.muted
                font: Tokens.font.body.small
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            ActionButton {
                label: root.running ? Tr.tr("Stop") : Tr.tr("Start")
                primary: true
                onClicked: root.running ? root.stop() : root.start()
            }

            ActionButton {
                label: Tr.tr("Lap")
                enabled: root.elapsed > 0
                onClicked: root.lap()
            }

            ActionButton {
                label: Tr.tr("Reset")
                enabled: root.elapsed > 0 || root.laps.length > 0
                onClicked: root.reset()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            spacing: Tokens.spacing.extraSmall / 2

            Repeater {
                model: root.laps

                delegate: Text {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Tr.tr("Lap %1").arg(root.laps.length - index) + "   " + root.formatTime(modelData)
                    color: root.muted
                    font: Tokens.font.mono.small
                    elide: Text.ElideRight
                }
            }
        }
    }
}
