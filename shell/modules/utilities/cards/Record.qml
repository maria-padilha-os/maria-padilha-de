pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services
import qs.utils

StyledRect {
    id: root

    required property var props
    required property ScreenState screenState

    readonly property bool recording: Recorder.running
    readonly property bool recordingMode: String(root.props.captureMode ?? "full").startsWith("record")
    readonly property bool countingDown: countdownLeft > 0
    readonly property string screenshotMode: {
        switch (root.props.captureMode) {
        case "window":
            return "window";
        case "region":
            return "region";
        default:
            return "full";
        }
    }
    readonly property string recordMode: {
        switch (root.props.captureMode) {
        case "record-window":
            return "window";
        case "record-region":
            return "region";
        default:
            return "full";
        }
    }
    readonly property string folder: root.recordingMode ? Config.utilities.capture.recordingDir : Config.utilities.capture.screenshotDir
    readonly property string statusText: {
        if (root.countingDown)
            // TRANSLATORS: %1 = seconds remaining
            return Tr.tr("Capturing in %1...").arg(root.countdownLeft);
        if (root.recording)
            return Recorder.paused ? Tr.trCtx("Paused", "recorder state") : Tr.trCtx("Recording...", "recorder state");
        if (Screenshot.busy)
            return Tr.tr("Saving screenshot...");
        if (Screenshot.error || Recorder.error)
            return Tr.tr("Something went wrong");
        return Tr.tr("Ready");
    }
    readonly property real nonAnimHeight: layout.implicitHeight + layout.anchors.margins * 2

    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2
    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    property int countdownLeft: 0
    property string pendingCapture: ""

    function startCapture(): void {
        if (root.recording || Screenshot.busy || root.countingDown)
            return;

        root.pendingCapture = root.recordingMode ? "record" : "screenshot";
        const wait = Math.max(0, Math.min(60, Config.utilities.capture.countdown));
        if (wait === 0) {
            finishCountdown();
            return;
        }
        root.countdownLeft = wait;
        countdownTimer.restart();
    }

    function finishCountdown(): void {
        const action = root.pendingCapture;
        root.pendingCapture = "";
        root.countdownLeft = 0;
        countdownTimer.stop();
        if (action === "record")
            root.startRecording();
        else if (action === "screenshot")
            root.takeScreenshot();
    }

    function cancelCountdown(): void {
        root.pendingCapture = "";
        root.countdownLeft = 0;
        countdownTimer.stop();
    }

    function takeScreenshot(): void {
        Screenshot.capture(root.screenshotMode, Config.utilities.capture.copyScreenshot);
    }

    function startRecording(): void {
        const args = ["--mode", root.recordMode];
        if (root.props.recordingSound)
            args.push("--sound");
        Recorder.start(args);
    }

    function activate(): void {
        if (root.countingDown)
            root.cancelCountdown();
        else if (root.recording)
            Recorder.stop();
        else
            root.startCapture();
    }

    Ref {
        service: Recorder
    }

    Ref {
        service: Screenshot
    }

    Timer {
        id: countdownTimer

        interval: 1000
        repeat: true

        onTriggered: {
            root.countdownLeft--;
            if (root.countdownLeft <= 0)
                root.finishCountdown();
        }
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            id: btnLayout

            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: {
                    const h = icon.implicitHeight + Tokens.padding.small * 2;
                    return h - (h % 2);
                }

                radius: Tokens.rounding.full
                color: {
                    if (root.recording)
                        return Recorder.paused ? Colours.palette.m3tertiary : Colours.palette.m3error;
                    if (root.countingDown)
                        return Colours.palette.m3tertiaryContainer;
                    return Colours.palette.m3secondaryContainer;
                }

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1
                    text: root.recording ? "screen_record" : root.recordingMode ? "videocam" : "screenshot_monitor"
                    color: root.recording ? (Recorder.paused ? Colours.palette.m3onTertiary : Colours.palette.m3onError) : root.countingDown ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Screenshots and recording")
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.statusText
                    color: Recorder.error || Screenshot.error ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                    animate: true
                }
            }

            IconButton {
                visible: root.recording
                icon: Recorder.paused ? "play_arrow" : "pause"
                isToggle: true
                checked: Recorder.paused
                type: IconButton.Tonal
                onClicked: Recorder.togglePause()

                implicitWidth: {
                    const h = label.implicitHeight + Tokens.padding.large * 2;
                    if (h % 2 !== 0)
                        return h + 1;
                    return h;
                }
            }

            TextButton {
                id: actionButton

                type: TextButton.Filled
                text: root.countingDown ? Tr.trCtx("Cancel", "capture action") : root.recording ? Tr.trCtx("Stop", "capture action") : Tr.trCtx("Start", "capture action")
                onClicked: root.activate()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            SplitButton {
                id: modeButton

                type: SplitButton.Tonal
                fallbackIcon: root.recordingMode ? "videocam" : "screenshot_monitor"
                disabled: root.recording || Screenshot.busy || root.countingDown
                active: modeButton.menuItems.find(item => item.value === (root.props.captureMode ?? "full")) ?? modeButton.menuItems[0]

                menu.onItemSelected: item => root.props.captureMode = item.value

                menuItems: [
                    MenuItem {
                        icon: "screenshot_monitor"
                        text: Tr.tr("Screenshot full screen")
                        activeText: Tr.tr("Full screen")
                        value: "full"
                    },
                    MenuItem {
                        icon: "select_window"
                        text: Tr.tr("Screenshot focused window")
                        activeText: Tr.tr("Focused window")
                        value: "window"
                    },
                    MenuItem {
                        icon: "screenshot_region"
                        text: Tr.tr("Screenshot region")
                        activeText: Tr.tr("Region")
                        value: "region"
                    },
                    MenuItem {
                        icon: "screen_record"
                        text: Tr.tr("Record full screen")
                        activeText: Tr.tr("Record screen")
                        value: "record"
                    },
                    MenuItem {
                        icon: "screen_share"
                        text: Tr.tr("Record focused window")
                        activeText: Tr.tr("Record window")
                        value: "record-window"
                    },
                    MenuItem {
                        icon: "videocam"
                        text: Tr.tr("Record region")
                        activeText: Tr.tr("Record region")
                        value: "record-region"
                    }
                ]
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: Tr.tr("Copy to clipboard")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                visible: !root.recordingMode
            }

            StyledSwitch {
                visible: !root.recordingMode
                checked: Config.utilities.capture.copyScreenshot
                onToggled: GlobalConfig.utilities.capture.copyScreenshot = checked
            }

            StyledText {
                text: Tr.tr("Include sound")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                visible: root.recordingMode
            }

            StyledSwitch {
                visible: root.recordingMode
                checked: root.props.recordingSound
                onToggled: root.props.recordingSound = checked
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Paths.shortenHome(root.folder)
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            elide: Text.ElideMiddle
        }

        StyledText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: Recorder.error || Screenshot.error
            color: Colours.palette.m3error
            font: Tokens.font.body.small
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Use an empty capture workspace. The command warns when the active workspace is not \"%1\".").arg(Config.utilities.capture.workspace)
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        StyledRect {
            Layout.fillWidth: true
            visible: root.countingDown
            implicitHeight: countdownText.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.medium
            color: Colours.palette.m3tertiaryContainer

            StyledText {
                id: countdownText

                anchors.centerIn: parent
                // TRANSLATORS: %1 = seconds remaining
                text: Tr.tr("Capturing in %1s - press Cancel to stop").arg(root.countdownLeft)
                color: Colours.palette.m3onTertiaryContainer
                font: Tokens.font.body.medium
            }
        }

        Loader {
            id: listOrControls

            property bool running: Recorder.running

            asynchronous: true
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            sourceComponent: running ? recordingControls : recordingList
            clip: Layout.preferredHeight < implicitHeight

            Behavior on Layout.preferredHeight {
                id: locHeightAnim

                enabled: false

                Anim {}
            }

            Behavior on running {
                SequentialAnimation {
                    Anim {
                        target: listOrControls
                        property: "opacity"
                        to: 0
                        type: Anim.DefaultEffects
                    }
                    PropertyAction {
                        target: locHeightAnim
                        property: "enabled"
                        value: true
                    }
                    PropertyAction {}
                    ParallelAnimation {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: 100
                            }
                            PropertyAction {
                                target: locHeightAnim
                                property: "enabled"
                                value: false
                            }
                        }
                        Anim {
                            target: listOrControls
                            property: "opacity"
                            to: 1
                            type: Anim.SlowEffects
                        }
                    }
                }
            }
        }
    }

    Component {
        id: recordingList

        RecordingList {
            props: root.props
            screenState: root.screenState
        }
    }

    Component {
        id: recordingControls

        RowLayout {
            spacing: Tokens.spacing.medium

            StyledRect {
                radius: Tokens.rounding.full
                color: Recorder.paused ? Colours.palette.m3tertiary : Colours.palette.m3error

                implicitWidth: recText.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: recText.implicitHeight + Tokens.padding.large

                StyledText {
                    id: recText

                    anchors.centerIn: parent
                    animate: true
                    text: Recorder.paused ? Tr.trCtx("PAUSED", "recording status") : Tr.trCtx("REC", "recording status")
                    color: Recorder.paused ? Colours.palette.m3onTertiary : Colours.palette.m3onError
                    font: Tokens.font.mono.small
                }

                Behavior on implicitWidth {
                    Anim {}
                }

                SequentialAnimation on opacity {
                    running: !Recorder.paused && !Accessibility.reducedMotion
                    alwaysRunToEnd: true
                    loops: Animation.Infinite

                    Anim {
                        from: 1
                        to: 0
                        duration: Accessibility.motion(Tokens.anim.durations.large)
                        easing: Tokens.anim.emphasizedAccel
                    }
                    Anim {
                        from: 0
                        to: 1
                        duration: Accessibility.motion(Tokens.anim.durations.extraLarge)
                        easing: Tokens.anim.emphasizedDecel
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    const elapsed = Recorder.elapsed;

                    const hours = Math.floor(elapsed / 3600);
                    const mins = Math.floor((elapsed % 3600) / 60);
                    const secs = Math.floor(elapsed % 60).toString().padStart(2, "0");

                    let time;
                    if (hours > 0)
                        time = `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
                    else
                        time = `${mins}:${secs}`;

                    // TRANSLATORS: %1 = elapsed recording duration, e.g. 01:23
                    return Tr.tr("Recording for %1").arg(time);
                }
                font: Tokens.font.body.medium
                elide: Text.ElideMiddle
            }

            ButtonRow {
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    shapeMorph: true
                    isRound: true
                    label.animate: true
                    icon: Recorder.paused ? "play_arrow" : "pause"
                    accessibleName: Recorder.paused ? Tr.tr("Resume recording") : Tr.tr("Pause recording")
                    isToggle: true
                    checked: Recorder.paused
                    type: IconButton.Tonal
                    font: Tokens.font.icon.medium
                    onClicked: {
                        Recorder.togglePause();
                        internalChecked = Recorder.paused;
                    }

                    implicitWidth: {
                        // Ensure even size so icon is centered properly
                        const h = label.implicitHeight + Tokens.padding.large * 2;
                        if (h % 2 !== 0)
                            return h + 1;
                        return h;
                    }
                }

                IconButton {
                    shapeMorph: true
                    isRound: true
                    icon: "stop"
                    accessibleName: Tr.tr("Stop recording")
                    inactiveColour: Colours.palette.m3error
                    inactiveOnColour: Colours.palette.m3onError
                    font: Tokens.font.icon.medium
                    onClicked: Recorder.stop()

                    implicitWidth: {
                        // Ensure even size so icon is centered properly
                        const h = label.implicitHeight + Tokens.padding.large * 2;
                        if (h % 2 !== 0)
                            return h + 1;
                        return h;
                    }
                }
            }
        }
    }
}
