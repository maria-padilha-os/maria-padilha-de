import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n

// Focus/break timer. The countdown is driven by a deadline so it stays
// accurate across suspends, and both the timer and the notification helper
// are inert while the tab is not selected. Closing the dashboard destroys the
// item, so no process outlives the tab.
Item {
    id: root

    property var api
    property bool active: true
    property bool compact: false

    property int focusMinutes: 25
    property int breakMinutes: 5
    property bool running: false
    property bool focusPhase: true
    property real remainingMs: root.focusMinutes * 60000
    property real deadline: 0
    property int completedCycles: 0
    property string status: ""

    readonly property var palette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color foreground: root.palette ? root.palette.m3onSurface : "transparent"
    readonly property color muted: root.palette ? root.palette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.palette ? root.palette.m3primary : "transparent"
    readonly property color onAccent: root.palette ? root.palette.m3onPrimary : "transparent"
    readonly property color tertiary: root.palette ? root.palette.m3tertiary : "transparent"
    readonly property color outline: root.palette ? root.palette.m3outlineVariant : "transparent"

    readonly property int phaseMinutes: root.focusPhase ? root.focusMinutes : root.breakMinutes
    readonly property real phaseTotalMs: root.phaseMinutes * 60000
    readonly property real progress: root.phaseTotalMs > 0 ? Math.max(0, Math.min(1, 1 - root.remainingMs / root.phaseTotalMs)) : 0
    readonly property string timeText: {
        const seconds = Math.max(0, Math.ceil(root.remainingMs / 1000));
        const minutes = Math.floor(seconds / 60);
        const rest = seconds % 60;
        return `${String(minutes).padStart(2, "0")}:${String(rest).padStart(2, "0")}`;
    }
    readonly property string phaseText: root.focusPhase ? Tr.tr("Focus") : Tr.tr("Break")

    function clampMinutes(value: int): int {
        return Math.max(1, Math.min(120, Math.round(value)));
    }

    function setFocusMinutes(value: int): void {
        root.focusMinutes = root.clampMinutes(value);
        if (!root.running && root.focusPhase)
            root.remainingMs = root.focusMinutes * 60000;
    }

    function setBreakMinutes(value: int): void {
        root.breakMinutes = root.clampMinutes(value);
        if (!root.running && !root.focusPhase)
            root.remainingMs = root.breakMinutes * 60000;
    }

    function start(): void {
        if (root.running)
            return;
        if (root.remainingMs <= 0)
            root.remainingMs = root.phaseTotalMs;
        root.deadline = Date.now() + root.remainingMs;
        root.status = "";
        root.running = true;
    }

    function pause(): void {
        if (!root.running)
            return;
        root.remainingMs = Math.max(0, root.deadline - Date.now());
        root.running = false;
    }

    function toggle(): void {
        if (root.running)
            root.pause();
        else
            root.start();
    }

    function reset(): void {
        root.running = false;
        root.focusPhase = true;
        root.completedCycles = 0;
        root.remainingMs = root.focusMinutes * 60000;
        root.deadline = 0;
        root.status = "";
    }

    function notify(title: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "Maria Padilha", "-i", "hourglass_top", title, body]);
    }

    function completePhase(withNotification: bool): void {
        const wasFocus = root.focusPhase;
        root.running = false;

        if (wasFocus) {
            root.completedCycles += 1;
            root.focusPhase = false;
            root.remainingMs = root.breakMinutes * 60000;
            root.status = Tr.tr("Focus complete. Time for a break.");
            if (withNotification)
                root.notify(Tr.tr("Focus complete"), Tr.tr("Take a %1 minute break.").arg(root.breakMinutes));
        } else {
            root.focusPhase = true;
            root.remainingMs = root.focusMinutes * 60000;
            root.status = Tr.tr("Break complete. Ready to focus.");
            if (withNotification)
                root.notify(Tr.tr("Break complete"), Tr.tr("Ready for another %1 minute focus session.").arg(root.focusMinutes));
        }
    }

    function nextPhase(): void {
        root.completePhase(false);
    }

    function tick(): void {
        if (!root.running)
            return;
        root.remainingMs = Math.max(0, root.deadline - Date.now());
        if (root.remainingMs <= 0)
            root.completePhase(true);
    }

    onActiveChanged: {
        if (!root.active && root.running)
            root.pause();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.running
        onTriggered: root.tick()
    }

    component ActionButton: Rectangle {
        id: button

        property string label
        property bool primary: false
        signal clicked

        implicitWidth: 84
        implicitHeight: 34
        radius: Tokens.rounding.full
        color: !button.enabled ? "transparent" : button.primary ? root.accent : buttonMouse.pressed ? Qt.alpha(root.accent, 0.18) : "transparent"
        border.width: button.primary ? 0 : 1
        border.color: root.outline
        opacity: button.enabled ? 1 : 0.45

        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.primary ? root.onAccent : root.foreground
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component DurationControl: RowLayout {
        id: control

        required property string label
        property int value: 25
        property int minimum: 1
        property int maximum: 120
        signal decreased
        signal increased

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        Text {
            Layout.fillWidth: true
            text: control.label
            color: root.muted
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        ActionButton {
            label: "−"
            implicitWidth: 30
            implicitHeight: 26
            enabled: !root.running && control.value > control.minimum
            onClicked: control.decreased()
        }

        Text {
            Layout.preferredWidth: 46
            horizontalAlignment: Text.AlignHCenter
            text: Tr.tr("%1 min").arg(control.value)
            color: root.foreground
            font.pixelSize: 12
            font.family: "monospace"
        }

        ActionButton {
            label: "+"
            implicitWidth: 30
            implicitHeight: 26
            enabled: !root.running && control.value < control.maximum
            onClicked: control.increased()
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.min(Math.max(280, root.width - (root.compact ? Tokens.padding.medium : Tokens.padding.large) * 2), 480)
        spacing: root.compact ? Tokens.spacing.small : Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Text {
                Layout.fillWidth: true
                text: Tr.tr("Pomodoro")
                color: root.foreground
                font.pixelSize: 20
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                text: Tr.tr("%1 cycles").arg(root.completedCycles)
                color: root.muted
                font.pixelSize: 12
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.phaseText
                color: root.focusPhase ? root.accent : root.tertiary
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.timeText
                color: root.foreground
                font.pixelSize: root.compact ? 44 : 56
                font.family: "monospace"
                font.weight: Font.DemiBold
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 8

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.alpha(root.outline, 0.35)
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: parent.width * root.progress
                    radius: height / 2
                    color: root.focusPhase ? root.accent : root.tertiary
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.status
            color: root.muted
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.extraSmall

            ActionButton {
                label: root.running ? Tr.tr("Pause") : Tr.tr("Start")
                primary: true
                onClicked: root.toggle()
            }

            ActionButton {
                label: Tr.tr("Reset")
                onClicked: root.reset()
            }

            ActionButton {
                label: Tr.tr("Skip")
                enabled: root.running || root.remainingMs < root.phaseTotalMs
                onClicked: root.nextPhase()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            spacing: Tokens.spacing.extraSmall

            DurationControl {
                label: Tr.tr("Focus length")
                value: root.focusMinutes
                minimum: 5
                maximum: 120
                onDecreased: root.setFocusMinutes(root.focusMinutes - 5)
                onIncreased: root.setFocusMinutes(root.focusMinutes + 5)
            }

            DurationControl {
                label: Tr.tr("Break length")
                value: root.breakMinutes
                minimum: 1
                maximum: 60
                onDecreased: root.setBreakMinutes(root.breakMinutes - 1)
                onIncreased: root.setBreakMinutes(root.breakMinutes + 1)
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
