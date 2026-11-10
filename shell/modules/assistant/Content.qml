pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property ScreenState screenState

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow
            clip: true

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
                    text: "Assistant"
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: Assistant.modelLabel
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                }

                IconButton {
                    icon: "add_comment"
                    onClicked: Assistant.newChat()
                }

                IconButton {
                    icon: "close"
                    onClicked: root.screenState.assistant = false
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Assistant.rootsLabel
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: Assistant.error.length > 0
                text: Assistant.error
                wrapMode: Text.Wrap
                font: Tokens.font.label.small
                color: Colours.palette.m3error
            }

            ListView {
                id: transcript

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Tokens.spacing.small
                model: Assistant.messages

                delegate: ColumnLayout {
                    required property var modelData

                    width: transcript.width
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.role === "user" ? "You" : (modelData.cancelled ? "Assistant · cancelled" : "Assistant")
                        font: Tokens.font.label.small
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
                            text: (modelData.text || (modelData.streaming ? "Thinking…" : "")) + (modelData.streaming ? " ▍" : "")
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            color: modelData.role === "user" ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        }
                    }
                }

                onCountChanged: positionViewAtEnd()
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
                        placeholderText: "Ask the assistant"
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.medium
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
                    text: Assistant.streaming ? "Stop" : "Send"
                    enabled: Assistant.streaming || (Assistant.ready && composer.text.trim().length > 0)
                    onClicked: Assistant.streaming ? Assistant.cancel() : Assistant.send(composer.text)
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Assistant.configured ? "Read-only · grants are managed by padilha-ai" : "Configure a provider in ~/.config/padilha/ai.lua"
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.tPalette.m3outlineVariant
        }
    }

    Keys.onEscapePressed: Assistant.cancelOrClose()
}
