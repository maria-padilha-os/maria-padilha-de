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
            anchors.margins: Tokens.padding.medium
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
                    id: historyButton

                    icon: "history"
                    accessibleName: Tr.tr("DSH sessions")
                    onClicked: sessionsPopup.open()
                }

                IconButton {
                    icon: "add_comment"
                    accessibleName: Tr.tr("New DSH session")
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
                text: Assistant.sessionLabel
                font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }

            Popup {
                id: sessionsPopup

                parent: historyButton
                x: historyButton.width - width
                y: historyButton.height + 6
                width: 360
                height: 360
                padding: 8
                modal: false
                focus: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                background: StyledRect {
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainerHigh
                }

                contentItem: ListView {
                    id: sessionsList

                    anchors.fill: parent
                    clip: true
                    model: Assistant.sessions
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: ItemDelegate {
                        id: sessionDelegate

                        required property var modelData

                        width: sessionsList.width
                        height: 56
                        padding: 0
                        onClicked: {
                            Assistant.selectSession(modelData.id);
                            sessionsPopup.close();
                        }

                        background: StyledRect {
                            radius: Tokens.rounding.small
                            color: sessionDelegate.hovered ? Colours.tPalette.m3surfaceContainerHighest : "transparent"
                        }

                        contentItem: StyledText {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.small
                            anchors.rightMargin: Tokens.padding.small
                            verticalAlignment: Text.AlignVCenter
                            text: sessionDelegate.modelData.title + (sessionDelegate.modelData.owned ? " · live" : "")
                            elide: Text.ElideRight
                            font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: Tokens.padding.small
                            anchors.rightMargin: Tokens.padding.small
                            anchors.bottomMargin: Tokens.padding.extraSmall
                            text: Qt.formatDateTime(new Date(sessionDelegate.modelData.updated), "dd/MM HH:mm")
                            elide: Text.ElideRight
                            font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
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

                    StyledRect {
                        id: bubble

                        readonly property bool fromUser: modelData.role === "user"
                        readonly property real maxBubbleWidth: transcript.width * 0.82

                        Layout.fillWidth: !fromUser
                        Layout.maximumWidth: fromUser ? maxBubbleWidth : transcript.width
                        Layout.preferredWidth: fromUser ? Math.min(maxBubbleWidth, body.implicitWidth + Tokens.padding.medium * 2) : transcript.width
                        Layout.alignment: fromUser ? Qt.AlignRight : Qt.AlignLeft
                        implicitHeight: body.implicitHeight + Tokens.padding.medium * 2
                        radius: Tokens.rounding.medium
                        color: fromUser ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

                        StyledText {
                            id: body

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                            text: (modelData.text || (modelData.streaming ? Tr.tr("Thinking…") : "")) + (modelData.streaming ? " ▍" : "")
                            wrapMode: Text.Wrap
                            textFormat: bubble.fromUser ? Text.PlainText : Text.MarkdownText
                            color: bubble.fromUser ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
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
                        placeholderText: Assistant.sessionOwned ? Tr.tr("Read-only session — start a new chat") : Tr.tr("Ask the assistant")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.builders.medium.scale(root.fontScale).build()
                        background: null
                        enabled: Assistant.ready && !Assistant.streaming && !Assistant.sessionOwned

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
                    enabled: Assistant.streaming || (Assistant.ready && !Assistant.sessionOwned && composer.text.trim().length > 0)
                    onClicked: Assistant.streaming ? Assistant.cancel() : Assistant.send(composer.text)
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Assistant.sessionOwned ? Tr.tr("Read-only · this session is open in dsh-tui") : (Assistant.configured ? Tr.tr("Local DeepSeek Harness session") : Tr.tr("DeepSeek Harness is not ready"))
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
