import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

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
    readonly property color cOutline: root.theme ? root.theme.m3outlineVariant : "transparent"
    readonly property color cError: root.theme ? root.theme.m3error : "transparent"
    readonly property color cOnError: root.theme ? root.theme.m3onError : "transparent"

    readonly property int minimumWidth: 360
    readonly property int minimumHeight: 240
    readonly property bool compact: root.height < Tokens.sizes.dashboard.mediaTabHeight
    readonly property int cardPadding: root.compact ? Tokens.padding.small : Tokens.padding.medium
    readonly property int controlHeight: Math.max(Tokens.font.label.medium.pointSize + Tokens.padding.small * 2, Tokens.padding.extraLarge + Tokens.padding.small)
    readonly property int gaugeTrackY: Tokens.spacing.extraLarge

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
            return Tr.tr("Stopped");
        if (root.lastError.length > 0)
            return root.lastError;
        if (!root.hasData)
            return Tr.tr("Listening…");
        if (!root.detected)
            return Tr.tr("Silence — play a string");
        if (root.inTune)
            return Tr.tr("In tune");
        return root.cents < 0 ? Tr.tr("Tune up") : Tr.tr("Tune down");
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

        anchors.centerIn: parent
        width: Math.min(Math.max(root.minimumWidth, parent.width - cardPadding * 2), 640)
        height: Math.min(Math.max(root.minimumHeight, parent.height - cardPadding * 2), 480)
        radius: Tokens.rounding.extraLarge
        color: root.cSurfaceHigh
        border.width: 1
        border.color: Qt.alpha(root.cOutline, 0.6)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.cardPadding
            spacing: root.compact ? Tokens.spacing.extraSmall : Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Text {
                    Layout.fillWidth: true
                    text: Tr.tr("Guitar tuner")
                    color: root.cOnSurface
                    font: Tokens.font.title.small
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: startButton

                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Math.max(startLabel.implicitWidth + Tokens.padding.large * 2, Tokens.padding.extraExtraLarge + Tokens.padding.small)
                    implicitHeight: root.controlHeight
                    radius: Tokens.rounding.full
                    color: root.running ? root.cError : root.cPrimary
                    opacity: root.pitchScript.length > 0 ? (startArea.containsMouse ? 0.9 : 1) : 0.45
                    border.width: startButton.activeFocus ? 2 : 0
                    border.color: root.cOnSurface
                    activeFocusOnTab: true

                    Accessible.role: Accessible.Button
                    Accessible.name: root.running ? Tr.tr("Stop listening") : Tr.tr("Start listening")

                    Keys.onReturnPressed: root.running ? root.stop() : root.start()
                    Keys.onSpacePressed: root.running ? root.stop() : root.start()

                    Behavior on color {
                        ColorAnimation {
                            duration: Tokens.anim.durations.expressiveFastEffects
                        }
                    }

                    Text {
                        id: startLabel

                        anchors.centerIn: parent
                        text: root.running ? Tr.tr("Stop") : Tr.tr("Start")
                        color: root.running ? root.cOnError : root.cOnPrimary
                        font: Tokens.font.label.medium
                    }

                    MouseArea {
                        id: startArea

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.pitchScript.length > 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            startButton.forceActiveFocus();
                            root.running ? root.stop() : root.start();
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.compact ? Tokens.padding.extraExtraLarge + Tokens.padding.medium : Tokens.padding.extraExtraLarge * 1.5
                spacing: Tokens.spacing.medium

                Text {
                    Layout.preferredWidth: Tokens.padding.extraExtraLarge * 2
                    Layout.fillHeight: true
                    text: root.detected ? root.note : "—"
                    color: root.detected ? (root.inTune ? root.cPrimary : root.cOnSurface) : root.cOnSurfaceVariant
                    font: root.compact ? Tokens.font.headline.medium : Tokens.font.headline.builders.large.scale(1.3).build()
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    Text {
                        text: root.centsText
                        color: root.detected ? (root.inTune ? root.cPrimary : root.cOnSurface) : root.cOnSurfaceVariant
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.frequencyText
                        color: root.cOnSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: referenceButton

                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Math.max(referenceLabel.implicitWidth + Tokens.padding.large * 2, Tokens.padding.extraExtraLarge * 2)
                    implicitHeight: root.controlHeight
                    radius: Tokens.rounding.full
                    color: refArea.containsMouse ? Qt.alpha(root.cPrimary, 0.28) : root.cSurfaceHighest
                    border.width: referenceButton.activeFocus ? 2 : 1
                    border.color: referenceButton.activeFocus ? root.cPrimary : Qt.alpha(root.cPrimary, 0.5)
                    activeFocusOnTab: true

                    Accessible.role: Accessible.Button
                    Accessible.name: Tr.tr("Play %1 reference").arg(root.selectedName)

                    Keys.onReturnPressed: root.playReference()
                    Keys.onSpacePressed: root.playReference()

                    Text {
                        id: referenceLabel

                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - Tokens.padding.small * 2)
                        text: root.referencePlaying ? Tr.tr("Playing…") : Tr.tr("Play %1").arg(root.selectedName)
                        color: root.cPrimary
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        id: refArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            referenceButton.forceActiveFocus();
                            root.playReference();
                        }
                    }
                }
            }

            Item {
                id: gauge

                Layout.fillWidth: true
                Layout.preferredHeight: root.compact ? Tokens.padding.extraLargeIncreased + Tokens.padding.small : Tokens.padding.extraExtraLarge

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
                    y: root.gaugeTrackY
                    height: Tokens.padding.extraSmall
                    radius: height / 2
                    color: root.cSurfaceHighest
                }

                Rectangle {
                    x: track.x + track.width * 0.45
                    y: track.y - Tokens.padding.extraSmall / 2
                    width: track.width * 0.1
                    height: track.height + Tokens.padding.extraSmall
                    radius: height / 2
                    color: Qt.alpha(root.cPrimary, 0.28)
                }

                Repeater {
                    model: 11

                    delegate: Rectangle {
                        required property int index

                        x: track.x + track.width * index / 10
                        y: index === 5 ? root.gaugeTrackY - Tokens.padding.small : root.gaugeTrackY - Tokens.padding.extraSmall
                        width: index === 5 ? 2 : 1
                        height: index === 5 ? Tokens.padding.large : Tokens.padding.small + 1
                        color: index === 5 ? root.cOnSurfaceVariant : Qt.alpha(root.cOnSurfaceVariant, 0.45)
                    }
                }

                Rectangle {
                    id: needle

                    visible: root.detected
                    y: root.gaugeTrackY - Tokens.padding.small
                    width: Tokens.padding.extraSmall
                    height: Tokens.padding.extraExtraLarge
                    radius: width / 2
                    x: track.x + track.width * (root.gaugeCents + 50) / 100 - width / 2
                    color: root.inTune ? root.cPrimary : root.cError

                    Behavior on x {
                        NumberAnimation {
                            duration: Tokens.anim.durations.expressiveFastEffects
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.controlHeight
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
                        Layout.preferredHeight: root.controlHeight
                        radius: Tokens.rounding.small
                        color: isMatch ? root.cPrimary : isSelected ? root.cPrimaryContainer : root.cSurfaceHighest
                        border.width: stringButton.activeFocus ? 2 : isSelected ? 1 : 0
                        border.color: root.cPrimary
                        activeFocusOnTab: true

                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData.name
                        Accessible.checked: stringButton.isSelected

                        Keys.onReturnPressed: root.selectedString = stringButton.index
                        Keys.onSpacePressed: root.selectedString = stringButton.index

                        Text {
                            anchors.centerIn: parent
                            width: Math.max(0, parent.width - Tokens.padding.extraSmall * 2)
                            text: stringButton.modelData.name
                            color: stringButton.isMatch ? root.cOnPrimary : stringButton.isSelected ? root.cOnPrimaryContainer : root.cOnSurfaceVariant
                            font: Tokens.font.label.medium
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                stringButton.forceActiveFocus();
                                root.selectedString = stringButton.index;
                            }
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
                    implicitWidth: Tokens.spacing.small
                    implicitHeight: Tokens.spacing.small
                    radius: Tokens.rounding.full
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
                    root.lastError = Tr.tr("Microphone unavailable");
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
