// ADR 0001 sketch — panel layout only. Not imported by shell.qml.
//
// The real module would live at shell/modules/assistant/ and talk to the
// Assistant service, which owns the JSON-lines child process. This file
// deliberately has no backend, no credential, and no file access.

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

    required property var screenState
    required property var assistant // sketch: Assistant.qml singleton

    readonly property var messages: assistant?.messages ?? []
    readonly property var models: assistant?.models ?? []
    readonly property bool streaming: assistant?.streaming ?? false
    readonly property var pendingConfirm: assistant?.pendingConfirm ?? null

    implicitWidth: 440
    implicitHeight: 720

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerLow

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            // Header: title, model selection, new chat, close.
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: "Assistant"
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3onSurface
                }

                ComboBox {
                    id: modelPicker

                    Layout.maximumWidth: 190
                    model: root.models
                    textRole: "name"
                    enabled: !root.streaming
                    onActivated: index => root.assistant.selectModel(root.models[index].id)
                }

                IconButton {
                    icon: "add_comment"
                    onClicked: root.assistant.newChat()
                }

                IconButton {
                    icon: "close"
                    onClicked: root.screenState.assistant = false
                }
            }

            // Effective roots, read-only by default.
            StyledText {
                Layout.fillWidth: true
                text: root.assistant?.rootsLabel ?? "No folders granted"
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }

            // Transcript. The real delegate renders plain text and fenced
            // code only, never HTML or remote images.
            ListView {
                id: transcript

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Tokens.spacing.small
                model: root.messages

                delegate: ColumnLayout {
                    required property var modelData

                    width: transcript.width
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.role === "user" ? "You" : "Assistant"
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
                            text: modelData.text + (modelData.streaming ? " ▍" : "")
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            color: modelData.role === "user" ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        }
                    }
                }

                onCountChanged: if (assistant?.stickToBottom ?? true) positionViewAtEnd()
            }

            // A native confirmation card; the model cannot press it.
            StyledRect {
                Layout.fillWidth: true
                visible: root.pendingConfirm !== null
                implicitHeight: confirmColumn.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: Colours.palette.m3secondaryContainer

                ColumnLayout {
                    id: confirmColumn

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: root.pendingConfirm?.title ?? ""
                        font: Tokens.font.title.small
                        color: Colours.palette.m3onSecondaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.pendingConfirm?.detail ?? ""
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        color: Colours.palette.m3onSecondaryContainer
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight

                        TextButton {
                            text: "Cancel"
                            onClicked: root.assistant.deny()
                        }

                        TextButton {
                            text: "Allow once"
                            type: TextButton.Filled
                            onClicked: root.assistant.confirm()
                        }
                    }
                }
            }

            // Composer. Enter sends; Shift+Enter inserts a newline.
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                IconButton {
                    icon: "attach_file"
                    enabled: !root.streaming
                    onClicked: root.assistant.attachFile()
                }

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
                        placeholderText: "Ask about a granted folder, or @ a file"
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.medium
                        background: null
                        enabled: !root.streaming

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                root.assistant.cancelOrClose();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    return;
                                root.assistant.send(text);
                                text = "";
                                event.accepted = true;
                            }
                        }
                    }
                }

                IconTextButton {
                    icon: root.streaming ? "stop" : "send"
                    text: root.streaming ? "Stop" : "Send"
                    enabled: root.streaming || composer.text.length > 0
                    onClicked: root.streaming ? root.assistant.cancel() : root.assistant.send(composer.text)
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.assistant?.statusLabel ?? "read-only"
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    Keys.onEscapePressed: root.assistant.cancelOrClose()
}
