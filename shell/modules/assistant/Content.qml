pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property ScreenState screenState

    // Slightly smaller than the shell default so the transcript fits more text.
    readonly property real fontScale: 0.92
    // True while the view should trail new turns; a manual scroll turns it off.
    property bool follow: true

    Component.onCompleted: {
        Assistant.start();
        root.focusComposer();
    }
    Component.onDestruction: Assistant.stop()

    function focusComposer(): void {
        if (root.screenState.assistant && Assistant.ready && !Assistant.streaming)
            Qt.callLater(() => composer.forceActiveFocus());
    }

    // positionViewAtEnd() is a no-op here once ListView reports atYEnd, so
    // assign the scroll offset directly and let the height handler repeat it
    // while delegates are still being laid out.
    function scrollToEnd(): void {
        transcript.contentY = Math.max(0, transcript.contentHeight - transcript.height);
    }

    Connections {
        function onReadyChanged(): void {
            root.focusComposer();
        }

        function onStreamingChanged(): void {
            if (!Assistant.streaming)
                root.focusComposer();
        }

        // Follow new turns as they arrive, but never fight a manual scroll:
        // contentHeight also grows while ListView instantiates delegates.
        function onMessagesChanged(): void {
            const last = Assistant.messages[Assistant.messages.length - 1];
            if (last && last.role === "user")
                root.follow = true;
            if (root.follow) {
                momentum.stop();
                Qt.callLater(() => root.scrollToEnd());
            }
        }

        target: Assistant
    }

    // Keep the view pinned while the follow flag is set. A one-shot scroll can
    // run before ListView has instantiated the last delegates and gets clamped;
    // repeating it while following survives that.
    Timer {
        interval: 120
        repeat: true
        running: root.follow
        onTriggered: {
            const maxY = Math.max(0, transcript.contentHeight - transcript.height);
            if (maxY > 0 && transcript.contentY < maxY - 1)
                transcript.contentY = maxY;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "auto_awesome"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Assistant")
                    font: Tokens.font.title.builders.medium.scale(root.fontScale).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: Assistant.modelLabel
                    font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                }

                IconButton {
                    icon: "add_comment"
                    accessibleName: Tr.tr("New assistant chat")
                    onClicked: Assistant.newChat()
                }

                IconButton {
                    icon: "close"
                    accessibleName: Tr.tr("Close assistant")
                    onClicked: root.screenState.assistant = false
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Assistant.rootsLabel
                font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: Assistant.error.length > 0
                text: Assistant.error
                wrapMode: Text.Wrap
                font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                color: Colours.palette.m3error
            }

            ListView {
                id: transcript

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Tokens.spacing.small
                model: Assistant.messages

                maximumFlickVelocity: 3000

                onDraggingChanged: {
                    if (dragging) {
                        root.follow = false;
                        momentum.stop();
                    }
                }
                onMovementEnded: {
                    if (atYEnd)
                        root.follow = true;
                }

                // A handler on top of the list: ListView's own wheel processing
                // swallowed events before a handler on the view saw them.
                MouseArea {
                    id: wheelArea

                    anchors.fill: parent
                    z: 100
                    acceptedButtons: Qt.NoButton
                    property real lastMove: 0

                    onWheel: event => {
                        const pixel = event.pixelDelta;
                        const angle = event.angleDelta;
                        const delta = pixel.y !== 0 ? pixel.y : angle.y / 120 * 90;
                        if (delta === 0)
                            return;
                        momentum.stop();
                        const maxY = Math.max(0, transcript.contentHeight - transcript.height);
                        const before = transcript.contentY;
                        transcript.contentY = Math.max(0, Math.min(maxY, before - delta * 4));
                        wheelArea.lastMove = transcript.contentY - before;
                        root.follow = transcript.contentY >= maxY - 2;
                        if (wheelArea.lastMove !== 0)
                            momentumTimer.restart();
                        event.accepted = true;
                    }
                }

                Timer {
                    id: momentumTimer

                    interval: 90
                    repeat: false
                    onTriggered: {
                        const extra = wheelArea.lastMove * 2.5;
                        if (Math.abs(extra) < 8)
                            return;
                        const maxY = Math.max(0, transcript.contentHeight - transcript.height);
                        momentum.from = transcript.contentY;
                        momentum.to = Math.max(0, Math.min(maxY, transcript.contentY + extra));
                        momentum.start();
                    }
                }

                NumberAnimation {
                    id: momentum

                    target: transcript
                    property: "contentY"
                    duration: 380
                    easing.type: Easing.OutCubic
                    onStopped: root.follow = transcript.contentY >= Math.max(0, transcript.contentHeight - transcript.height) - 2
                }

                delegate: ColumnLayout {
                    required property var modelData

                    width: transcript.width
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.role === "user" ? Tr.trCtx("You", "chat message author") : (modelData.cancelled ? Tr.trCtx("Assistant · cancelled", "chat message author and state") : Tr.trCtx("Assistant", "chat message author"))
                        font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: body.implicitHeight + Tokens.padding.medium * 2
                        radius: Tokens.rounding.medium
                        color: modelData.role === "user" ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

                        StyledText {
                            id: body

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                            text: (modelData.text || (modelData.streaming ? Tr.tr("Thinking…") : "")) + (modelData.streaming ? " ▍" : "")
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            color: modelData.role === "user" ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        }
                    }
                }

                onCountChanged: {
                    if (root.follow)
                        Qt.callLater(() => root.scrollToEnd());
                }
                onContentHeightChanged: {
                    if (root.follow)
                        Qt.callLater(() => root.scrollToEnd());
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: composer.implicitHeight + Tokens.padding.medium * 2
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainerHigh

                    TextArea {
                        id: composer

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        wrapMode: TextArea.Wrap
                        placeholderText: Tr.tr("Ask the assistant")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.builders.medium.scale(root.fontScale).build()
                        background: null
                        enabled: Assistant.ready && !Assistant.streaming

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                Assistant.cancelOrClose();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    return;
                                Assistant.send(text);
                                text = "";
                                event.accepted = true;
                            }
                        }
                    }
                }

                IconTextButton {
                    icon: Assistant.streaming ? "stop" : "send"
                    text: Assistant.streaming ? Tr.tr("Stop") : Tr.tr("Send")
                    enabled: Assistant.streaming || (Assistant.ready && composer.text.trim().length > 0)
                    onClicked: Assistant.streaming ? Assistant.cancel() : Assistant.send(composer.text)
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Assistant.configured ? Tr.tr("Read-only · grants are managed by padilha-ai") : Tr.tr("Configure a provider in ~/.config/padilha/ai.lua")
                font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }
        }

        StyledRect {
            Layout.topMargin: Tokens.padding.large - Tokens.spacing.medium
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.tPalette.m3outlineVariant
        }
    }

    Keys.onEscapePressed: Assistant.cancelOrClose()
}
