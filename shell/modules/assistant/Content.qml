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

    Component.onCompleted: {
        Assistant.start();
        root.focusComposer();
    }
    Component.onDestruction: Assistant.stop()

    function focusComposer(): void {
        if (root.screenState.assistant && Assistant.ready && !Assistant.streaming)
            Qt.callLater(() => composer.forceActiveFocus());
    }

    Connections {
        function onReadyChanged(): void {
            root.focusComposer();
        }

        function onStreamingChanged(): void {
            if (!Assistant.streaming)
                root.focusComposer();
        }

        // Follow the conversation only when its content changes (send, reply,
        // restore). Following contentHeight also snapped the view back while
        // scrolling, because ListView grows its estimate as delegates appear.
        function onMessagesChanged(): void {
            Qt.callLater(() => transcript.positionViewAtEnd());
        }

        target: Assistant
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

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: transcript
                }

                maximumFlickVelocity: 3000

                // Qt follows wheel deltas almost 1:1, which feels sluggish;
                // scale them like the shell's other flickables.
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                    onWheel: event => {
                        const pixel = event.pixelDelta;
                        const angle = event.angleDelta;
                        const delta = pixel.y !== 0 ? pixel.y : angle.y / 120 * 90;
                        if (delta === 0)
                            return;
                        const maxY = Math.max(0, transcript.contentHeight - transcript.height);
                        transcript.contentY = Math.max(0, Math.min(maxY, transcript.contentY - delta * 4));
                        event.accepted = true;
                    }
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
                            textFormat: modelData.role === "user" ? Text.PlainText : Text.MarkdownText
                            color: modelData.role === "user" ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        }
                    }
                }

                onCountChanged: Qt.callLater(() => positionViewAtEnd())
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
