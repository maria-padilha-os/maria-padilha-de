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
    readonly property int wheelDiameter: 220
    property real wheelHue: 0
    property real wheelSaturation: 0

    function hueToRgb(p: real, q: real, t: real): real {
        if (t < 0)
            t += 1;
        if (t > 1)
            t -= 1;
        if (t < 1 / 6)
            return p + (q - p) * 6 * t;
        if (t < 1 / 2)
            return q;
        if (t < 2 / 3)
            return p + (q - p) * (2 / 3 - t) * 6;
        return p;
    }

    function hslToRgb(h: real, s: real, l: real): var {
        const hue = h / 360;
        if (s <= 0) {
            const grey = Math.round(l * 255);
            return [grey, grey, grey];
        }
        const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        const p = 2 * l - q;
        return [
            Math.round(root.hueToRgb(p, q, hue + 1 / 3) * 255),
            Math.round(root.hueToRgb(p, q, hue) * 255),
            Math.round(root.hueToRgb(p, q, hue - 1 / 3) * 255)
        ];
    }

    function rgbToHsl(r: real, g: real, b: real): var {
        const red = r / 255;
        const green = g / 255;
        const blue = b / 255;
        const maximum = Math.max(red, green, blue);
        const minimum = Math.min(red, green, blue);
        const lightness = (maximum + minimum) / 2;
        if (maximum === minimum)
            return [0, 0, lightness];
        const delta = maximum - minimum;
        const saturation = lightness > 0.5 ? delta / (2 - maximum - minimum) : delta / (maximum + minimum);
        let hue = 0;
        if (maximum === red)
            hue = (green - blue) / delta + (green < blue ? 6 : 0);
        else if (maximum === green)
            hue = (blue - red) / delta + 2;
        else
            hue = (red - green) / delta + 4;
        return [hue * 60, saturation, lightness];
    }

    function hexByte(value: int): string {
        return (value < 16 ? "0" : "") + value.toString(16);
    }

    function applyColour(hexValue: string, rgbValue: string, hslValue: string): void {
        hex = hexValue;
        rgb = rgbValue;
        hsl = hslValue;
        const hslMatch = hslValue.match(/hsl\(\s*([\d.]+)\s*,\s*([\d.]+)%\s*,\s*([\d.]+)%\s*\)/i);
        if (hslMatch) {
            wheelHue = parseFloat(hslMatch[1]);
            wheelSaturation = parseFloat(hslMatch[2]) / 100;
        } else {
            const rgbMatch = rgbValue.match(/rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/i);
            if (rgbMatch) {
                const parts = root.rgbToHsl(Number(rgbMatch[1]), Number(rgbMatch[2]), Number(rgbMatch[3]));
                wheelHue = parts[0];
                wheelSaturation = parts[1];
            }
        }
        colourWheel.requestPaint();
    }

    function setWheelColour(hue: real, saturation: real): void {
        const rgbParts = root.hslToRgb(hue, saturation, 0.5);
        const hexValue = "#" + root.hexByte(rgbParts[0]) + root.hexByte(rgbParts[1]) + root.hexByte(rgbParts[2]);
        root.applyColour(hexValue, `rgb(${rgbParts[0]}, ${rgbParts[1]}, ${rgbParts[2]})`, `hsl(${Math.round(hue)}, ${Math.round(saturation * 100)}%, 50%)`);
    }

    onWheelHueChanged: colourWheel.requestPaint()
    onWheelSaturationChanged: colourWheel.requestPaint()

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
            root.applyColour(data.hex, data.rgb, data.hsl);
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

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
            border.width: pickButton.activeFocus ? 2 : 0
            border.color: root.accent
            activeFocusOnTab: !root.picking

            Accessible.role: Accessible.Button
            Accessible.name: root.picking ? Tr.tr("Picking a colour") : Tr.tr("Pick colour")
            Accessible.description: Tr.tr("Sample a colour from the screen")
            Accessible.focusable: !root.picking
            Accessible.focused: activeFocus
            Accessible.onPressAction: root.pick()

            Keys.onReturnPressed: root.pick()
            Keys.onEnterPressed: root.pick()
            Keys.onSpacePressed: root.pick()

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
                onPressed: pickButton.forceActiveFocus()
                onClicked: root.pick()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            radius: Tokens.rounding.large
            color: root.hasColour ? root.hex : root.surface
            border.width: 1
            border.color: root.outline
            clip: true

            Text {
                anchors.centerIn: parent
                text: root.hasColour ? root.hex.toUpperCase() : Tr.tr("No colour picked")
                color: root.hasColour && root.api && root.api.colours ? root.api.colours.on(root.hex) : root.muted
                font.pixelSize: root.hasColour ? 20 : 12
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
            id: copyButton

            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: Tokens.rounding.medium
            color: root.hasColour ? root.surface : "transparent"
            border.width: copyButton.activeFocus ? 2 : 1
            border.color: copyButton.activeFocus ? root.accent : root.outline
            opacity: root.hasColour ? 1 : 0.55
            activeFocusOnTab: root.hasColour && !copyProc.running

            Accessible.role: Accessible.Button
            Accessible.name: root.copied ? Tr.tr("Copied") : Tr.tr("Copy HEX colour")
            Accessible.description: root.hex
            Accessible.focusable: root.hasColour && !copyProc.running
            Accessible.focused: activeFocus
            Accessible.onPressAction: root.copy(root.hex)

            Keys.onReturnPressed: root.copy(root.hex)
            Keys.onEnterPressed: root.copy(root.hex)
            Keys.onSpacePressed: root.copy(root.hex)

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
                onClicked: {
                    copyButton.forceActiveFocus();
                    root.copy(root.hex);
                }
            }
        }
    
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: Tokens.spacing.small

            Item {
                id: wheelBox

                Layout.preferredWidth: root.wheelDiameter
                Layout.preferredHeight: root.wheelDiameter

                Canvas {
                    id: colourWheel

                    anchors.fill: parent

                    onPaint: {
                        const ctx = getContext("2d");
                        const cx = width / 2;
                        const cy = height / 2;
                        const radius = Math.min(cx, cy) - 2;
                        ctx.clearRect(0, 0, width, height);

                        for (let angle = 0; angle < 360; angle += 1) {
                            const start = (angle - 0.7) * Math.PI / 180;
                            const end = (angle + 0.7) * Math.PI / 180;
                            ctx.beginPath();
                            ctx.moveTo(cx, cy);
                            ctx.arc(cx, cy, radius, start, end);
                            ctx.closePath();
                            const rgbParts = root.hslToRgb(angle, 1, 0.5);
                            ctx.fillStyle = "#" + root.hexByte(rgbParts[0]) + root.hexByte(rgbParts[1]) + root.hexByte(rgbParts[2]);
                            ctx.fill();
                        }

                        const fade = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius);
                        fade.addColorStop(0, "rgba(255, 255, 255, 1)");
                        fade.addColorStop(1, "rgba(255, 255, 255, 0)");
                        ctx.beginPath();
                        ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                        ctx.fillStyle = fade;
                        ctx.fill();

                        ctx.beginPath();
                        ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                        ctx.lineWidth = 1;
                        ctx.strokeStyle = root.outline;
                        ctx.stroke();

                        const markerAngle = root.wheelHue * Math.PI / 180;
                        const markerRadius = radius * root.wheelSaturation;
                        const mx = cx + Math.cos(markerAngle) * markerRadius;
                        const my = cy + Math.sin(markerAngle) * markerRadius;
                        ctx.beginPath();
                        ctx.arc(mx, my, 7, 0, Math.PI * 2);
                        ctx.lineWidth = 2;
                        ctx.strokeStyle = "rgba(255, 255, 255, 1)";
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.arc(mx, my, 8, 0, Math.PI * 2);
                        ctx.lineWidth = 1;
                        ctx.strokeStyle = "rgba(0, 0, 0, 0.55)";
                        ctx.stroke();
                    }

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const cx = colourWheel.width / 2;
                        const cy = colourWheel.height / 2;
                        const radius = Math.min(cx, cy) - 2;
                        const dx = mouse.x - cx;
                        const dy = mouse.y - cy;
                        let hue = Math.atan2(dy, dx) * 180 / Math.PI;
                        if (hue < 0)
                            hue += 360;
                        root.setWheelColour(hue, Math.min(1, Math.sqrt(dx * dx + dy * dy) / radius));
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.hasColour ? root.hex.toUpperCase() : Tr.tr("Click the wheel")
                color: root.muted
                font.pixelSize: 12
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
        border.width: row.activeFocus ? 2 : 1
        border.color: row.activeFocus ? root.accent : root.outline
        activeFocusOnTab: row.value.length > 0

        Accessible.role: Accessible.Button
        Accessible.name: row.label + ": " + row.value
        Accessible.description: Tr.tr("Copy this value")
        Accessible.focusable: row.value.length > 0
        Accessible.focused: activeFocus
        Accessible.onPressAction: root.copy(row.value)

        Keys.onReturnPressed: root.copy(row.value)
        Keys.onEnterPressed: root.copy(row.value)
        Keys.onSpacePressed: root.copy(row.value)

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
            onClicked: {
                row.forceActiveFocus();
                root.copy(row.value);
            }
        }
    }
}
