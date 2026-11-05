import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config

// Guitar tuner. The shell hands us `api` (colours, paths, extension, ...) and
// api.extension.dirPath tells us where pitch.py lives.
Item {
    id: root

    property var api

    implicitWidth: 420
    implicitHeight: 260

    // api is assigned after the Loader creates the item, so every theme lookup
    // below tolerates a null palette and updates once api arrives.
    readonly property var theme: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color cPrimary: root.theme ? root.theme.m3primary : "transparent"
    readonly property color cOnPrimary: root.theme ? root.theme.m3onPrimary : "transparent"
    readonly property color cPrimaryContainer: root.theme ? root.theme.m3primaryContainer : "transparent"
    readonly property color cOnPrimaryContainer: root.theme ? root.theme.m3onPrimaryContainer : "transparent"
    readonly property color cSurfaceHigh: root.theme ? root.theme.m3surfaceContainerHigh : "transparent"
    readonly property color cSurfaceHighest: root.theme ? root.theme.m3surfaceContainerHighest : "transparent"
    readonly property color cOnSurface: root.theme ? root.theme.m3onSurface : "transparent"
    readonly property color cOnSurfaceVariant: root.theme ? root.theme.m3onSurfaceVariant : "transparent"
    readonly property color cError: root.theme ? root.theme.m3error : "transparent"
    readonly property color cOnError: root.theme ? root.theme.m3onError : "transparent"

    readonly property var strings: [
        {
            name: "E2",
            hz: 82.41
        },
        {
            name: "A2",
            hz: 110.0
        },
        {
            name: "D3",
            hz: 146.83
        },
        {
            name: "G3",
            hz: 196.0
        },
        {
            name: "B3",
            hz: 246.94
        },
        {
            name: "E4",
            hz: 329.63
        }
    ]

    property int selectedString: 0
    property bool running: false
    property bool hasData: false
    property bool sampleParsed: false
    property int failures: 0
    property string lastError: ""
    property real frequency: 0
    property real cents: 0
    property real rms: 0
    property string note: ""
    property bool referencePlaying: false

    readonly property bool detected: root.frequency > 0 && root.note.length > 0
    readonly property bool inTune: root.detected && Math.abs(root.cents) <= 5
    readonly property string selectedName: root.strings[root.selectedString] ? root.strings[root.selectedString].name : "E2"
    readonly property real selectedHz: root.strings[root.selectedString] ? root.strings[root.selectedString].hz : 82.41
    readonly property real gaugeCents: Math.max(-50, Math.min(50, root.cents))
    readonly property string pitchScript: root.api && root.api.extension && root.api.extension.dirPath ? root.api.extension.dirPath + "/pitch.py" : ""

    readonly property string centsText: {
        if (!root.detected)
            return "—";
        const sign = root.cents > 0 ? "+" : "";
        return sign + root.cents.toFixed(1) + " cents";
    }
    readonly property string frequencyText: root.detected ? root.frequency.toFixed(2) + " Hz" : "— Hz"
    readonly property string statusText: {
        if (!root.running)
            return "Stopped";
        if (root.lastError.length > 0)
            return root.lastError;
        if (!root.hasData)
            return "Listening…";
        if (!root.detected)
            return "Silence — play a string";
        if (root.inTune)
            return "In tune";
        return root.cents < 0 ? "Tune up" : "Tune down";
    }
    readonly property color statusColour: {
        if (!root.running)
            return root.cOnSurfaceVariant;
        if (root.lastError.length > 0)
            return root.cError;
        if (!root.detected)
            return root.cOnSurfaceVariant;
        return root.inTune ? root.cPrimary : root.cError;
    }

    function start() {
        if (!root.pitchScript)
            return;
        root.running = true;
        root.failures = 0;
        root.lastError = "";
        root.hasData = false;
        root.frequency = 0;
        root.note = "";
        root.cents = 0;
        root.rms = 0;
        root.runSample();
    }

    function stop() {
        root.running = false;
        sampleProc.running = false;
        refProc.running = false;
        root.referencePlaying = false;
        root.sampleParsed = false;
    }

    function runSample() {
        if (!root.running || !root.pitchScript || sampleProc.running)
            return;
        root.sampleParsed = false;
        sampleProc.running = true;
    }

    function parseSample(output) {
        const lines = (output || "").trim().split("\n");
        for (let i = lines.length - 1; i >= 0; i--) {
            const line = lines[i].trim();
            if (line.length === 0 || line[0] !== "{")
                continue;
            try {
                const data = JSON.parse(line);
                if (typeof data.freq !== "number")
                    continue;
                root.frequency = data.freq;
                root.note = data.note || "";
                root.cents = data.cents || 0;
                root.rms = data.rms || 0;
                root.hasData = true;
                return true;
            } catch (error) {
                // Try an earlier line; a stray warning must not hide the JSON.
            }
        }
        return false;
    }

    function playReference() {
        if (refProc.running)
            return;
        root.referencePlaying = true;
        refProc.running = true;
    }

    Component.onDestruction: root.stop()

    Rectangle {
        id: card

        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: root.cSurfaceHigh
        border.width: 1
        border.color: Qt.alpha(root.cOnSurfaceVariant, 0.18)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Text {
                    Layout.fillWidth: true
                    text: "Guitar tuner"
                    color: root.cOnSurface
                    font: Tokens.font.title.small
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: startButton

                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 86
                    implicitHeight: 32
                    radius: height / 2
                    color: root.running ? root.cError : root.cPrimary
                    opacity: root.pitchScript.length > 0 ? (startArea.containsMouse ? 0.9 : 1) : 0.45

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.running ? "Stop" : "Start"
                        color: root.running ? root.cOnError : root.cOnPrimary
                        font: Tokens.font.label.medium
                    }

                    MouseArea {
                        id: startArea

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.pitchScript.length > 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.running ? root.stop() : root.start()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 66
                spacing: Tokens.spacing.medium

                Text {
                    Layout.preferredWidth: 104
                    Layout.fillHeight: true
                    text: root.detected ? root.note : "—"
                    color: root.detected ? (root.inTune ? root.cPrimary : root.cOnSurface) : root.cOnSurfaceVariant
                    font: Tokens.font.headline.builders.large.size(42).weight(Font.DemiBold).build()
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    Text {
                        text: root.centsText
                        color: root.detected ? (root.inTune ? root.cPrimary : root.cOnSurface) : root.cOnSurfaceVariant
                        font: Tokens.font.title.small
                    }

                    Text {
                        text: root.frequencyText
                        color: root.cOnSurfaceVariant
                        font: Tokens.font.body.small
                    }
                }

                Rectangle {
                    id: referenceButton

                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 108
                    implicitHeight: 30
                    radius: height / 2
                    color: refArea.containsMouse ? Qt.alpha(root.cPrimary, 0.28) : root.cSurfaceHighest
                    border.width: 1
                    border.color: Qt.alpha(root.cPrimary, 0.5)

                    Text {
                        anchors.centerIn: parent
                        text: root.referencePlaying ? "Playing…" : "Play " + root.selectedName
                        color: root.cPrimary
                        font: Tokens.font.label.small
                    }

                    MouseArea {
                        id: refArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.playReference()
                    }
                }
            }

            Item {
                id: gauge

                Layout.fillWidth: true
                Layout.preferredHeight: 48

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "-50"
                    color: root.cOnSurfaceVariant
                    font: Tokens.font.label.small
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: "0"
                    color: root.cOnSurfaceVariant
                    font: Tokens.font.label.small
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: "+50"
                    color: root.cOnSurfaceVariant
                    font: Tokens.font.label.small
                }

                Rectangle {
                    id: track

                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: 27
                    height: 4
                    radius: 2
                    color: root.cSurfaceHighest
                }

                Rectangle {
                    x: track.x + track.width * 0.45
                    y: track.y - 2
                    width: track.width * 0.1
                    height: track.height + 4
                    radius: 2
                    color: Qt.alpha(root.cPrimary, 0.28)
                }

                Repeater {
                    model: 11

                    delegate: Rectangle {
                        required property int index

                        x: track.x + track.width * index / 10
                        y: index === 5 ? 22 : 24
                        width: index === 5 ? 2 : 1
                        height: index === 5 ? 14 : 9
                        color: index === 5 ? root.cOnSurfaceVariant : Qt.alpha(root.cOnSurfaceVariant, 0.45)
                    }
                }

                Rectangle {
                    id: needle

                    visible: root.detected
                    y: 17
                    width: 4
                    height: 24
                    radius: 2
                    x: track.x + track.width * (root.gaugeCents + 50) / 100 - width / 2
                    color: root.inTune ? root.cPrimary : root.cError

                    Behavior on x {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.strings

                    delegate: Rectangle {
                        id: stringButton

                        required property int index
                        required property var modelData

                        readonly property bool isSelected: root.selectedString === index
                        readonly property bool isMatch: root.detected && root.note === modelData.name

                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: Tokens.rounding.small
                        color: isMatch ? root.cPrimary : isSelected ? root.cPrimaryContainer : root.cSurfaceHighest
                        border.width: isSelected ? 1 : 0
                        border.color: root.cPrimary

                        Text {
                            anchors.centerIn: parent
                            text: stringButton.modelData.name
                            color: stringButton.isMatch ? root.cOnPrimary : stringButton.isSelected ? root.cOnPrimaryContainer : root.cOnSurfaceVariant
                            font: Tokens.font.label.medium
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedString = stringButton.index
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.small

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 7
                    implicitHeight: 7
                    radius: 3.5
                    color: root.statusColour
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.statusText
                    color: root.statusColour
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }
    }

    Timer {
        id: sampleTimer

        interval: 1200
        repeat: true
        running: root.running
        onTriggered: root.runSample()
    }

    Process {
        id: sampleProc

        command: ["sh", "-c", "timeout 2 parec --format=s16le --rate=22050 --channels=1 --latency-msec=100 2>/dev/null | head -c 8192 | python3 \"$1\"", "sh", root.pitchScript]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.running)
                    return;
                root.sampleParsed = root.parseSample(text);
                if (root.sampleParsed) {
                    root.failures = 0;
                    root.lastError = "";
                }
            }
        }

        onExited: {
            if (!root.running)
                return;
            if (!root.sampleParsed) {
                root.failures += 1;
                if (root.failures >= 2)
                    root.lastError = "Microphone unavailable";
            }
        }
    }

    Process {
        id: refProc

        command: ["ffplay", "-nodisp", "-autoexit", "-f", "lavfi", "-i", "sine=frequency=" + root.selectedHz.toFixed(2) + ":duration=1"]
        onExited: root.referencePlaying = false
        onStarted: root.referencePlaying = true
    }
}
