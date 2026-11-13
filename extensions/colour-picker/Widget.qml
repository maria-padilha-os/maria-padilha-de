import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// Dashboard extension: sample a screen colour and copy its HEX, RGB or HSL.
// It deliberately imports only the public extension API (api.colours) and
// standard QML so it also loads in the headless extension test harness.
Item {
    id: root

    property var api
    property bool active: true

    property string hex
    property string rgb
    property string hsl
    property string statusText: Tr.tr("Nothing is sampled until you press Pick colour")
    property string statusKind: "idle"
    property bool copied
    property string pendingCopyValue

    readonly property var themePalette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color foreground: root.themePalette ? root.themePalette.m3onSurface : "transparent"
    readonly property color muted: root.themePalette ? root.themePalette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.themePalette ? root.themePalette.m3primary : "transparent"
    readonly property color onAccent: root.themePalette ? root.themePalette.m3onPrimary : "transparent"
    readonly property color surface: root.themePalette ? root.themePalette.m3surfaceContainerHigh : "transparent"
    readonly property color outline: root.themePalette ? root.themePalette.m3outlineVariant : "transparent"
    readonly property color danger: root.themePalette ? root.themePalette.m3error : "transparent"

    readonly property bool hasColour: hex.length > 0
    readonly property bool picking: pickProc.running
    readonly property real contentWidth: Math.min(width, 360)

    function pick(): void {
        if (pickProc.running)
            return;

        copyTimer.stop();
        copied = false;
        statusKind = "idle";
        statusText = Tr.tr("Click anywhere on the screen to sample a colour. Escape cancels.");
        pickProc.running = true;
    }

    function copy(value: string): void {
        if (!value || copyProc.running)
            return;

        pendingCopyValue = value;
        copyTimer.stop();
        copied = false;
        copyProc.command = ["padilha-colour", "copy", value];
        copyProc.running = true;
    }

    function handlePick(code: int, output: string, errorOutput: string): void {
        if (code === 3) {
            statusKind = "idle";
            statusText = Tr.tr("Selection cancelled");
            return;
        }
        if (code === 5) {
            statusKind = "error";
            statusText = Tr.tr("The colour picker is not installed");
            return;
        }

        const raw = output.trim();
        if (raw.length === 0) {
            statusKind = "error";
            statusText = errorOutput.trim() || Tr.tr("The picker returned no colour");
            return;
        }

        try {
            const data = JSON.parse(raw);
            if (!data.hex || !data.rgb || !data.hsl)
                throw new Error("missing colour fields");
            hex = data.hex;
            rgb = data.rgb;
            hsl = data.hsl;
            if (code === 0) {
                statusKind = "ok";
                statusText = Tr.tr("Colour copied to the clipboard");
            } else if (code === 4) {
                statusKind = "error";
                statusText = Tr.tr("Colour ready, but the clipboard is unavailable");
            } else {
                statusKind = "error";
                statusText = errorOutput.trim() || Tr.tr("The picker returned an unexpected result");
            }
        } catch (e) {
            statusKind = "error";
            statusText = errorOutput.trim() || Tr.tr("Could not read the picker output");
        }
    }

    onActiveChanged: {
        if (!active && pickProc.running)
            pickProc.running = false;
    }

    Component.onDestruction: {
        if (pickProc.running)
            pickProc.running = false;
        if (copyProc.running)
            copyProc.running = false;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.contentWidth
        spacing: Tokens.spacing.small

        Text {
            Layout.fillWidth: true
            text: Tr.tr("Colour picker")
            color: root.foreground
            font.pixelSize: 15
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: root.statusText
            color: root.statusKind === "error" ? root.danger : root.muted
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Rectangle {
            id: pickButton

            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: Tokens.rounding.medium
            color: root.picking ? root.surface : root.accent
            opacity: root.picking ? 0.65 : 1

            Text {
                anchors.centerIn: parent
                text: root.picking ? Tr.tr("Picking…") : Tr.tr("Pick colour")
                color: root.picking ? root.muted : root.onAccent
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                enabled: !root.picking
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pick()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 104
            radius: Tokens.rounding.large
            color: root.hasColour ? root.hex : root.surface
            border.width: 1
            border.color: root.outline
            clip: true

            Text {
                anchors.centerIn: parent
                text: root.hasColour ? root.hex.toUpperCase() : Tr.tr("No colour picked")
                color: root.hasColour && root.api && root.api.colours ? root.api.colours.on(root.hex) : root.muted
                font.pixelSize: root.hasColour ? 22 : 12
                font.weight: root.hasColour ? Font.Medium : Font.Normal
            }
        }

        ValueRow {
            Layout.fillWidth: true
            label: "HEX"
            value: root.hex
        }

        ValueRow {
            Layout.fillWidth: true
            label: "RGB"
            value: root.rgb
        }

        ValueRow {
            Layout.fillWidth: true
            label: "HSL"
            value: root.hsl
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: Tokens.rounding.medium
            color: root.hasColour ? root.surface : "transparent"
            border.width: 1
            border.color: root.outline
            opacity: root.hasColour ? 1 : 0.55

            Text {
                anchors.centerIn: parent
                text: root.copied ? Tr.tr("Copied") : Tr.tr("Copy HEX")
                color: root.foreground
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.hasColour && !copyProc.running
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copy(root.hex)
            }
        }
    }

    Timer {
        id: copyTimer

        interval: 1600
        onTriggered: root.copied = false
    }

    Process {
        id: pickProc

        command: ["padilha-colour", "pick", "--json"]
        stdout: StdioCollector {
            id: pickOutput
        }
        stderr: StdioCollector {
            id: pickError
        }
        onExited: code => Qt.callLater(() => root.handlePick(code, pickOutput.text, pickError.text))
    }

    Process {
        id: copyProc

        stderr: StdioCollector {
            id: copyError
        }
        onExited: code => {
            Qt.callLater(() => {
                if (code === 0) {
                    root.copied = true;
                    root.statusKind = "ok";
                    root.statusText = Tr.tr("Copied %1").arg(root.pendingCopyValue);
                    copyTimer.restart();
                } else {
                    root.copied = false;
                    root.statusKind = "error";
                    root.statusText = copyError.text.trim() || Tr.tr("Could not copy to the clipboard");
                }
            });
        }
    }

    component ValueRow: Rectangle {
        id: row

        required property string label
        required property string value

        implicitHeight: 38
        radius: Tokens.rounding.medium
        color: root.surface
        border.width: 1
        border.color: root.outline

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            Text {
                text: row.label
                color: root.muted
                font.pixelSize: 12
            }

            Text {
                Layout.fillWidth: true
                text: row.value
                color: root.foreground
                font.family: "monospace"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: row.value.length > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: root.copy(row.value)
        }
    }
}
