import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Virtualized message stack. Historical messages use a lightweight Markdown
// text delegate; only the current assistant answer gets the rich code/copy
// renderer. ListView only instantiates the rows near the viewport.
Item {
    id: root

    required property var messages
    property real fontScale: 0.92
    property bool follow: true
    property bool positioning: false
    property string sessionKey: ""
    property real lastContentY: 0

    readonly property ListView view: list
    readonly property real maxY: Math.max(0, list.contentHeight - list.height)
    readonly property bool atBottom: list.contentY >= maxY - 2
    readonly property bool jumpVisible: jumpButton.visible

    signal copyRequested(string text)

    function clampBottom(): void {
        const max = Math.max(0, list.contentHeight - list.height);
        if (list.contentY > max)
            list.contentY = max;
        else if (list.contentY < 0)
            list.contentY = 0;
    }

    function forceEnd(): void {
        list.positionViewAtEnd();
        const max = Math.max(0, list.contentHeight - list.height);
        if (list.contentY < max)
            list.contentY = max;
    }

    function scrollToBottom(): void {
        root.positioning = true;
        list.positionViewAtEnd();
        Qt.callLater(root.clampBottom);
        settle.restart();
    }

    Timer {
        id: settle

        interval: 220
        repeat: false
        onTriggered: {
            if (root.follow) {
                root.forceEnd();
                Qt.callLater(root.clampBottom);
            }
        }
    }

    Timer {
        id: chase

        interval: 80
        repeat: false
        onTriggered: {
            if (!root.follow)
                return;
            root.forceEnd();
            root.clampBottom();
        }
    }

    Timer {
        id: slowSettle

        interval: 900
        repeat: false
        onTriggered: {
            if (root.follow) {
                root.forceEnd();
                Qt.callLater(root.clampBottom);
            }
            root.positioning = false;
        }
    }

    function scheduleFollow(): void {
        if (!root.follow)
            return;
        Qt.callLater(() => root.scrollToBottom());
        slowSettle.restart();
    }

    function breakFollow(): void {
        root.follow = false;
    }

    onSessionKeyChanged: {
        root.follow = true;
        root.scheduleFollow();
    }
    Component.onCompleted: root.scheduleFollow()

    ListView {
        id: list

        anchors.fill: parent
        clip: true
        spacing: Tokens.spacing.small
        boundsBehavior: Flickable.StopAtBounds
        maximumFlickVelocity: 3000
        model: root.messages
        cacheBuffer: 120

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: list
        }

        delegate: Item {
            id: row

            required property var modelData

            readonly property bool fromUser: modelData.role === "user"
            readonly property bool rich: !fromUser && modelData.rich === true
            readonly property string bodyText: String(modelData.text || "")

            width: list.width
            height: bodyText.trim().length === 0 ? 0 : bubble.height

            StyledRect {
                id: bubble

                width: row.width
                height: (row.rich ? richLoader.height : plainBody.implicitHeight) + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: row.fromUser ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

                HoverHandler {
                    id: bubbleHover
                }

                TextEdit {
                    id: plainBody

                    x: Tokens.padding.medium
                    y: Tokens.padding.medium
                    width: bubble.width - Tokens.padding.medium * 2
                    height: implicitHeight
                    visible: !row.rich
                    readOnly: true
                    selectByMouse: true
                    persistentSelection: true
                    font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                    text: row.bodyText
                    wrapMode: TextEdit.Wrap
                    textFormat: row.fromUser ? TextEdit.PlainText : TextEdit.MarkdownText
                    color: row.fromUser ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    selectionColor: Colours.palette.m3primary
                    selectedTextColor: Colours.palette.m3onPrimary
                }

                Loader {
                    id: richLoader

                    x: Tokens.padding.medium
                    y: Tokens.padding.medium
                    width: bubble.width - Tokens.padding.medium * 2
                    height: item ? item.implicitHeight : 0
                    active: row.rich
                    visible: row.rich

                    sourceComponent: Component {
                        MarkdownBody {
                            width: richLoader.width
                            text: row.bodyText
                            streaming: row.modelData.streaming === true
                            fontScale: root.fontScale
                            allowPrivileged: !row.fromUser

                            onCopyRequested: text => root.copyRequested(text)
                        }
                    }
                }

                Item {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 4
                    implicitWidth: 22
                    implicitHeight: 22
                    z: 2
                    visible: bubbleHover.hovered && row.bodyText.length > 0

                    Accessible.role: Accessible.Button
                    Accessible.name: Tr.tr("Copy message")
                    Accessible.onPressAction: root.copyRequested(row.bodyText)

                    StyledRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        color: copyMouse.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, copyMouse.pressed ? 0.2 : 0.12) : "transparent"
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "content_copy"
                        color: Colours.palette.m3onSurface
                        fontStyle: Tokens.font.icon.small
                    }

                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyRequested(row.bodyText)
                    }
                }
            }
        }

        onCountChanged: root.scheduleFollow()
        onContentHeightChanged: {
            if (root.follow)
                chase.restart();
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
            const y = list.contentY;
            if (!root.positioning && y < root.lastContentY - 2)
                root.breakFollow();
            root.lastContentY = y;
            if (root.positioning)
                return;
            if (root.atBottom)
                root.follow = true;
            // A changing contentHeight can temporarily move contentY away from
            // the end while delegates are still being created. Only an actual
            // user movement (or an upward wheel/drag) breaks follow.
        }
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
            root.scrollToBottom();
        }
    }
}
