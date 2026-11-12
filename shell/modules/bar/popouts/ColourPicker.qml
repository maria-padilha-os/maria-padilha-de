pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    property string hex
    property string rgb
    property string hsl
    property string statusText: Tr.tr("Nothing is sampled until you press Pick colour")
    property string statusKind: "idle" // idle, ok or error
    property bool copied
    property string pendingCopyValue

    readonly property bool hasColour: hex.length > 0
    readonly property bool picking: pickProc.running

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

    implicitWidth: 300
    width: implicitWidth
    spacing: Tokens.spacing.small

    Component.onDestruction: {
        // The popout can close while hyprpicker is waiting for a click. Do
        // not leave that process behind; the picker only ever runs while the
        // panel that owns it is open.
        if (pickProc.running)
            pickProc.running = false;
        if (copyProc.running)
            copyProc.running = false;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Colour picker")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        MaterialIcon {
            text: "palette"
            color: Colours.palette.m3secondary
            fontStyle: Tokens.font.icon.medium
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: root.statusText
        color: root.statusKind === "error" ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
        wrapMode: Text.Wrap
    }

    IconTextButton {
        Layout.fillWidth: true
        icon: root.picking ? "hourglass_top" : "colorize"
        text: root.picking ? Tr.tr("Picking…") : Tr.tr("Pick colour")
        type: IconTextButton.Tonal
        disabled: root.picking
        onClicked: root.pick()
    }

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: 112
        radius: Tokens.rounding.large
        color: root.hasColour ? root.hex : Colours.tPalette.m3surfaceContainerHigh
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
        clip: true

        StyledText {
            anchors.centerIn: parent
            text: root.hasColour ? root.hex.toUpperCase() : Tr.tr("No colour picked")
            color: root.hasColour ? Colours.on(root.hex) : Colours.palette.m3onSurfaceVariant
            font: root.hasColour ? Tokens.font.title.medium : Tokens.font.body.small
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

    IconTextButton {
        Layout.fillWidth: true
        icon: root.copied ? "check" : "content_copy"
        text: root.copied ? Tr.tr("Copied") : Tr.tr("Copy HEX")
        type: IconTextButton.Filled
        disabled: !root.hasColour || copyProc.running
        onClicked: root.copy(root.hex)
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
        onExited: code => Qt.callLater(() => root.handlePick(code, pickOutput.text, pickError.text)) // qmllint disable signal-handler-parameters
    }

    Process {
        id: copyProc

        stderr: StdioCollector {
            id: copyError
        }
        onExited: code => { // qmllint disable signal-handler-parameters
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

    component ValueRow: StyledRect {
        id: row

        required property string label
        required property string value

        implicitWidth: rowLayout.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: rowLayout.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.medium
        color: rowMouse.containsMouse ? Colours.tPalette.m3surfaceContainerHighest : Colours.tPalette.m3surfaceContainerHigh
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
        clip: true

        StateLayer {
            id: rowMouse

            radius: row.radius
            onClicked: root.copy(row.value)
        }

        RowLayout {
            id: rowLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.small

            StyledText {
                text: row.label
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }

            StyledText {
                Layout.fillWidth: true
                text: row.value
                color: Colours.palette.m3onSurface
                font: Tokens.font.mono.small
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }

            MaterialIcon {
                text: "content_copy"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }
        }
    }
}
