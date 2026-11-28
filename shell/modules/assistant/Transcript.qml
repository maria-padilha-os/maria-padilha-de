import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Exact-height transcript. Unlike ListView, the content height is the sum of
// the actual delegates, so auto-follow can never position past the last item.
Item {
    id: root

    required property var messages
    property real fontScale: 0.92
    property bool follow: true
    property bool positioning: false

    readonly property Flickable view: flick
    readonly property real maxY: Math.max(0, flick.contentHeight - flick.height)
    readonly property bool atBottom: flick.contentY >= maxY - 2
    readonly property bool jumpVisible: jumpButton.visible

    signal copyRequested(string text)

    function scrollToBottom(): void {
        root.positioning = true;
        flick.contentY = root.maxY;
        Qt.callLater(() => root.positioning = false);
    }

    function scheduleFollow(): void {
        if (root.follow)
            settle.restart();
    }

    function breakFollow(): void {
        root.follow = false;
        settle.stop();
    }

    Timer {
        id: settle

        interval: 500
        repeat: false
        onTriggered: {
            if (root.follow)
                root.scrollToBottom();
        }
    }

    onMessagesChanged: root.scheduleFollow()
    onMaxYChanged: root.scheduleFollow()

    Component.onCompleted: root.scheduleFollow()

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        maximumFlickVelocity: 3000
        flickableDirection: Flickable.VerticalFlick

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: flick
        }

        Column {
            id: column

            width: flick.width
            spacing: Tokens.spacing.small

            onImplicitHeightChanged: root.scheduleFollow()

            Repeater {
                model: root.messages

                delegate: ColumnLayout {
                    id: message

                    required property var modelData

                    width: column.width
                    spacing: Tokens.spacing.extraSmall

                    StyledRect {
                        id: bubble

                        readonly property bool fromUser: message.modelData.role === "user"
                        readonly property bool hasCode: !fromUser && (message.modelData.text || "").indexOf("```") !== -1
                        readonly property real maxBubbleWidth: column.width * 0.82

                        Layout.fillWidth: !fromUser
                        Layout.maximumWidth: fromUser ? maxBubbleWidth : column.width
                        Layout.preferredWidth: fromUser ? Math.min(maxBubbleWidth, body.contentWidth + Tokens.padding.medium * 2) : column.width
                        Layout.alignment: fromUser ? Qt.AlignRight : Qt.AlignLeft
                        visible: fromUser || !message.modelData.streaming || message.modelData.text.length > 0
                        implicitHeight: (hasCode ? richBody.implicitHeight : body.contentHeight) + Tokens.padding.medium * 2
                        radius: Tokens.rounding.medium
                        color: fromUser ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

                        HoverHandler {
                            id: bubbleHover
                        }

                        Item {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 4
                            implicitWidth: 22
                            implicitHeight: 22
                            z: 2
                            visible: bubbleHover.hovered && message.modelData.text.length > 0

                            Accessible.role: Accessible.Button
                            Accessible.name: Tr.tr("Copy message")
                            Accessible.onPressAction: root.copyRequested(message.modelData.text)

                            StyledRect {
                                anchors.fill: parent
                                radius: Tokens.rounding.full
                                color: copyMouse.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, copyMouse.pressed ? 0.2 : 0.12) : "transparent"
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "content_copy"
                                color: bubble.fromUser ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                fontStyle: Tokens.font.icon.small
                            }

                            MouseArea {
                                id: copyMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyRequested(message.modelData.text)
                            }
                        }

                        TextEdit {
                            id: body

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            visible: !bubble.hasCode
                            readOnly: true
                            selectByMouse: true
                            persistentSelection: true
                            font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                            text: message.modelData.text || ""
                            wrapMode: TextEdit.Wrap
                            textFormat: bubble.fromUser ? TextEdit.PlainText : TextEdit.MarkdownText
                            color: bubble.fromUser ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            selectionColor: Colours.palette.m3primary
                            selectedTextColor: Colours.palette.m3onPrimary
                        }

                        MarkdownBody {
                            id: richBody

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            visible: bubble.hasCode
                            text: message.modelData.text || ""
                            streaming: message.modelData.streaming === true
                            fontScale: root.fontScale
                            allowPrivileged: !bubble.fromUser

                            onCopyRequested: text => root.copyRequested(text)
                        }
                    }
                }
            }
        }

        onMovementStarted: {
            if (!root.positioning)
                root.breakFollow();
        }
        onMovementEnded: {
            if (!root.positioning)
                root.follow = root.atBottom;
        }
        onContentYChanged: {
            if (root.positioning)
                return;
            if (root.atBottom)
                root.follow = true;
            else
                root.breakFollow();
        }
        onContentHeightChanged: root.scheduleFollow()
        onHeightChanged: root.scheduleFollow()
    }

    IconButton {
        id: jumpButton
        objectName: "scrollToBottomButton"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.medium
        z: 2
        visible: !root.follow && root.maxY > 1
        icon: "arrow_downward"
        type: IconButton.Filled
        isRound: true
        accessibleName: Tr.tr("Scroll to bottom")

        onClicked: {
            root.follow = true;
            root.scheduleFollow();
        }
    }
}
