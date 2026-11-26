pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services

Item {
    id: root

    required property ScreenState screenState

    // Slightly smaller than the shell default so the transcript fits more text.
    readonly property real fontScale: 0.92
    property int historyIndex: -1
    property string historyDraft: ""
    property string queuedText: ""
    property var queuedAttachments: []
    property var attachmentPaths: []
    property bool activityExpanded: false
    property bool showArchived: false
    property bool dropActive: false
    property string renameTargetId: ""

    function questions(): var {
        const out = [];
        for (const message of Assistant.messages) {
            if (message.role === "user" && typeof message.text === "string" && message.text.length > 0)
                out.push(message.text);
        }
        return out;
    }

    function resetHistory(): void {
        root.historyIndex = -1;
        root.historyDraft = "";
    }

    function recallPrevious(): bool {
        const entries = root.questions();
        if (entries.length === 0)
            return false;
        if (root.historyIndex < 0) {
            root.historyDraft = composer.text;
            root.historyIndex = entries.length - 1;
        } else if (root.historyIndex > 0) {
            root.historyIndex--;
        }
        composer.text = entries[root.historyIndex];
        composer.cursorPosition = composer.text.length;
        return true;
    }

    function recallNext(): bool {
        const entries = root.questions();
        if (root.historyIndex < 0)
            return false;
        if (root.historyIndex < entries.length - 1) {
            root.historyIndex++;
            composer.text = entries[root.historyIndex];
        } else {
            root.historyIndex = -1;
            composer.text = root.historyDraft;
        }
        composer.cursorPosition = composer.text.length;
        return true;
    }

    function openRename(id: string, title: string): void {
        root.renameTargetId = id;
        renameField.text = title;
        renamePopup.open();
    }

    function saveRename(): void {
        if (root.renameTargetId.length === 0)
            return;
        Assistant.renameSession(root.renameTargetId, renameField.text);
        root.renameTargetId = "";
        renamePopup.close();
    }

    function submitComposer(): void {
        const text = composer.text.trim();
        if (text.length === 0 && root.attachmentPaths.length === 0)
            return;
        if (Assistant.streaming) {
            root.queueComposer();
            return;
        }
        if (!Assistant.ready || Assistant.sessionOwned)
            return;
        Assistant.send(text, root.attachmentPaths.slice());
        composer.text = "";
        root.attachmentPaths = [];
        root.resetHistory();
    }

    function queueComposer(): void {
        const text = composer.text.trim();
        if (text.length === 0 && root.attachmentPaths.length === 0)
            return;
        root.queuedText = text;
        root.queuedAttachments = root.attachmentPaths.slice();
        composer.text = "";
        root.attachmentPaths = [];
        root.resetHistory();
    }

    function sendQueued(): void {
        if ((root.queuedText.length === 0 && root.queuedAttachments.length === 0) || Assistant.streaming || !Assistant.ready || Assistant.sessionOwned)
            return;
        const text = root.queuedText;
        const attachments = root.queuedAttachments.slice();
        root.queuedText = "";
        root.queuedAttachments = [];
        Assistant.send(text, attachments);
    }

    function addAttachment(path: string): void {
        if (root.attachmentPaths.length >= 4 || root.attachmentPaths.indexOf(path) !== -1)
            return;
        root.attachmentPaths = root.attachmentPaths.concat([path]);
    }

    function removeAttachment(index: int): void {
        const next = root.attachmentPaths.slice();
        next.splice(index, 1);
        root.attachmentPaths = next;
    }

    function copyMessage(text: string): void {
        if (!text)
            return;
        copyMessageProc.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", text];
        copyMessageProc.running = true;
    }

    Component.onCompleted: {
        Assistant.start();
        const dictated = VoiceInput.takeTranscript();
        if (dictated.length > 0) {
            composer.text = dictated;
            composer.cursorPosition = composer.text.length;
        }
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
            if (Assistant.streaming)
                return;
            root.focusComposer();
            if (Assistant.lastStop === "complete" && root.queuedText.length > 0)
                Qt.callLater(() => root.sendQueued());
        }

        // Follow the conversation only when its content changes (send, reply,
        // restore). Following contentHeight also snapped the view back while
        // scrolling, because ListView grows its estimate as delegates appear.
        function onMessagesChanged(): void {
            Qt.callLater(() => transcript.positionViewAtEnd());
        }

        function onSessionIdChanged(): void {
            root.resetHistory();
            root.queuedText = "";
            root.queuedAttachments = [];
            root.attachmentPaths = [];
            root.activityExpanded = false;
        }

        function onSessionsRequested(): void {
            sessionsPopup.open();
        }

        function onCloseRequested(): void {
            root.screenState.assistant = false;
        }

        target: Assistant
    }

    Process {
        id: copyMessageProc

        command: ["true"]
    }

    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: root.dropActive = true
        onExited: root.dropActive = false
        onDropped: drop => {
            for (let i = 0; i < drop.urls.length; i++) {
                let path = String(drop.urls[i]);
                if (path.startsWith("file://"))
                    path = decodeURIComponent(path.slice(7));
                root.addAttachment(path);
            }
            root.dropActive = false;
            drop.acceptProposedAction();
        }
    }

    Popup {
        id: renamePopup

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 340
        padding: 12
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: Qt.callLater(() => renameField.forceActiveFocus())

        background: StyledRect {
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainerHigh
        }

        contentItem: ColumnLayout {
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Rename session")
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.small.scale(root.fontScale).build()
            }

            TextField {
                id: renameField

                Layout.fillWidth: true
                color: Colours.palette.m3onSurface
                placeholderTextColor: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                background: StyledRect {
                    radius: Tokens.rounding.small
                    color: Colours.tPalette.m3surfaceContainerHighest
                }
                onAccepted: root.saveRename()
                Keys.onEscapePressed: renamePopup.close()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                Item { Layout.fillWidth: true }

                IconTextButton {
                    icon: "close"
                    text: Tr.tr("Cancel")
                    onClicked: renamePopup.close()
                }

                IconTextButton {
                    icon: "check"
                    text: Tr.tr("Save")
                    onClicked: root.saveRename()
                }
            }
        }
    }

    FileDialog {
        id: attachmentDialog

        title: Tr.tr("Attach files")
        filterLabel: Tr.tr("Files")
        filters: ["*"]
        onAccepted: path => root.addAttachment(path)
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
                onOpened: {
                    sessionSearch.text = "";
                    Qt.callLater(() => sessionSearch.forceActiveFocus());
                }

                background: StyledRect {
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainerHigh
                }

                contentItem: ColumnLayout {
                    spacing: Tokens.spacing.extraSmall

                    TextField {
                        id: sessionSearch

                        Layout.fillWidth: true
                        focus: true
                        placeholderText: Tr.tr("Search sessions")
                        color: Colours.palette.m3onSurface
                        placeholderTextColor: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                        background: StyledRect {
                            radius: Tokens.rounding.small
                            color: Colours.tPalette.m3surfaceContainerHighest
                        }
                    }

                    ListView {
                    id: sessionsList

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: {
                        Assistant.pinned; // Re-sort when a pin changes.
                        const query = sessionSearch.text.trim().toLowerCase();
                        const visible = Assistant.sessions.filter(session => root.showArchived || !Assistant.isArchived(session.id));
                        const filtered = query.length === 0 ? visible : visible.filter(session => String(Assistant.sessionTitleFor(session.id, session.title)).toLowerCase().includes(query));
                        return filtered.slice().sort((a, b) => Number(Assistant.isPinned(b.id)) - Number(Assistant.isPinned(a.id)));
                    }
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
                            anchors.rightMargin: 128
                            verticalAlignment: Text.AlignVCenter
                            text: Assistant.sessionTitleFor(sessionDelegate.modelData.id, sessionDelegate.modelData.title) + (sessionDelegate.modelData.owned ? " · live" : "")
                            elide: Text.ElideRight
                            font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                            color: Colours.palette.m3onSurface
                        }

                        RowLayout {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            IconButton {
                                icon: "edit"
                                accessibleName: Tr.tr("Rename session")
                                onClicked: root.openRename(sessionDelegate.modelData.id, Assistant.sessionTitleFor(sessionDelegate.modelData.id, sessionDelegate.modelData.title))
                            }

                            IconButton {
                                icon: Assistant.isArchived(sessionDelegate.modelData.id) ? "unarchive" : "archive"
                                accessibleName: Assistant.isArchived(sessionDelegate.modelData.id) ? Tr.tr("Unarchive session") : Tr.tr("Archive session")
                                onClicked: Assistant.toggleArchived(sessionDelegate.modelData.id)
                            }

                            IconButton {
                                icon: Assistant.isPinned(sessionDelegate.modelData.id) ? "star" : "star_border"
                                accessibleName: Assistant.isPinned(sessionDelegate.modelData.id) ? Tr.tr("Unpin session") : Tr.tr("Pin session")
                                onClicked: Assistant.togglePin(sessionDelegate.modelData.id)
                            }
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    IconButton {
                        icon: root.showArchived ? "visibility_off" : "visibility"
                        accessibleName: root.showArchived ? Tr.tr("Hide archived sessions") : Tr.tr("Show archived sessions")
                        onClicked: root.showArchived = !root.showArchived
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.showArchived ? Tr.tr("Archived sessions shown") : Tr.tr("Show archived sessions")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                        elide: Text.ElideRight
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

            Connections {
                function onTranscriptChanged(): void {
                    const dictated = VoiceInput.takeTranscript();
                    if (dictated.length === 0)
                        return;
                    composer.text = dictated;
                    composer.cursorPosition = composer.text.length;
                    root.resetHistory();
                }

                target: VoiceInput
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
                        Layout.preferredWidth: fromUser ? Math.min(maxBubbleWidth, body.contentWidth + Tokens.padding.medium * 2) : transcript.width
                        Layout.alignment: fromUser ? Qt.AlignRight : Qt.AlignLeft
                        visible: fromUser || !modelData.streaming || modelData.text.length > 0
                        implicitHeight: body.contentHeight + Tokens.padding.medium * 2
                        radius: Tokens.rounding.medium
                        color: fromUser ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

                        HoverHandler {
                            id: bubbleHover
                        }

                        IconButton {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            z: 2
                            visible: bubbleHover.hovered && modelData.text.length > 0
                            icon: "content_copy"
                            accessibleName: Tr.tr("Copy message")
                            onClicked: root.copyMessage(modelData.text)
                        }

                        TextEdit {
                            id: body

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            readOnly: true
                            selectByMouse: true
                            persistentSelection: true
                            font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                            text: modelData.text || ""
                            wrapMode: TextEdit.Wrap
                            textFormat: bubble.fromUser ? TextEdit.PlainText : TextEdit.MarkdownText
                            color: bubble.fromUser ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            selectionColor: Colours.palette.m3primary
                            selectedTextColor: Colours.palette.m3onPrimary
                        }
                    }
                }

                onCountChanged: Qt.callLater(() => positionViewAtEnd())
            }

            RowLayout {
                id: activityRow

                Layout.fillWidth: true
                visible: Assistant.streaming
                spacing: Tokens.spacing.small

                TapHandler {
                    onTapped: root.activityExpanded = !root.activityExpanded
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                MaterialIcon {
                    id: activityIcon

                    text: "progress_activity"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                    transformOrigin: Item.Center

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: activityRow.visible && !Accessibility.reducedMotion
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Assistant.activity.length > 0 ? Assistant.activity : Tr.tr("Thinking…")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    visible: Assistant.activityLog.length > 1
                    text: root.activityExpanded ? "expand_less" : "expand_more"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.activityExpanded && Assistant.activityLog.length > 1
                spacing: 0

                Repeater {
                    model: Assistant.activityLog.slice(-8)

                    delegate: StyledText {
                        required property string modelData

                        Layout.fillWidth: true
                        text: "• " + modelData
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                id: attachmentRow

                Layout.fillWidth: true
                visible: root.attachmentPaths.length > 0
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.attachmentPaths

                    delegate: StyledRect {
                        id: attachmentChip

                        required property string modelData
                        required property int index
                        readonly property bool isImage: /\.(png|jpe?g|webp|gif)$/i.test(modelData)

                        Layout.preferredWidth: attachmentChipContent.implicitWidth + Tokens.padding.small * 2
                        Layout.preferredHeight: 32
                        radius: Tokens.rounding.small
                        color: Colours.tPalette.m3surfaceContainerHigh
                        clip: true

                        RowLayout {
                            id: attachmentChipContent

                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.small
                            anchors.rightMargin: Tokens.padding.extraSmall
                            spacing: Tokens.spacing.extraSmall

                            Image {
                                visible: attachmentChip.isImage
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                source: visible ? encodeURI("file://" + attachmentChip.modelData) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.split("/").pop()
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                                elide: Text.ElideMiddle
                            }

                            IconButton {
                                icon: "close"
                                accessibleName: Tr.tr("Remove attachment")
                                onClicked: root.removeAttachment(index)
                            }
                        }
                    }
                }
            }

            RowLayout {
                id: queuedRow

                Layout.fillWidth: true
                visible: root.queuedText.length > 0
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "schedule"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Queued · sends after this turn: %1").arg(root.queuedText + (root.queuedAttachments.length > 0 ? (root.queuedText.length > 0 ? " " : "") + Tr.trN("[%n image]", "[%n images]", root.queuedAttachments.length) : ""))
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                    elide: Text.ElideRight
                }

                IconButton {
                    visible: !Assistant.streaming
                    icon: "send"
                    accessibleName: Tr.tr("Send queued message")
                    onClicked: root.sendQueued()
                }

                IconButton {
                    icon: "close"
                    accessibleName: Tr.tr("Discard queued message")
                    onClicked: root.queuedText = ""
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
                    border.width: root.dropActive ? 2 : 0
                    border.color: Colours.palette.m3primary

                    TextArea {
                        id: composer

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        wrapMode: TextArea.Wrap
                        placeholderText: VoiceInput.dictating ? Tr.tr("Listening… speak now") : (Assistant.sessionOwned ? Tr.tr("Read-only session — start a new chat") : (Assistant.streaming ? Tr.tr("Type while the assistant works — Enter queues") : Tr.tr("Ask the assistant")))
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.builders.medium.scale(root.fontScale).build()
                        background: null
                        // Keep the draft editable while the answer streams;
                        // Enter waits for the current turn to finish instead of
                        // sending a second prompt into an active turn.
                        enabled: Assistant.ready && !Assistant.sessionOwned

                        Keys.onPressed: event => {
                            const plain = !(event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
                            if (event.key === Qt.Key_Up && plain && (composer.text.indexOf("\n") === -1 || composer.cursorPosition === 0)) {
                                if (root.recallPrevious())
                                    event.accepted = true;
                            } else if (event.key === Qt.Key_Down && plain && (composer.text.indexOf("\n") === -1 || composer.cursorPosition === composer.text.length)) {
                                if (root.recallNext())
                                    event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                Assistant.cancelOrClose();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    return;
                                root.submitComposer();
                                event.accepted = true;
                            }
                        }
                    }
                }

                IconButton {
                    icon: "attach_file"
                    accessibleName: Tr.tr("Attach images")
                    enabled: !Assistant.sessionOwned
                    onClicked: attachmentDialog.open()
                }

                IconButton {
                    icon: VoiceInput.dictating ? "stop_circle" : "mic"
                    accessibleName: VoiceInput.dictating ? Tr.tr("Stop dictation") : Tr.tr("Dictate a message")
                    enabled: Assistant.ready && !Assistant.sessionOwned
                    onClicked: VoiceInput.dictate()
                }

                IconButton {
                    visible: Assistant.streaming && (composer.text.trim().length > 0 || root.attachmentPaths.length > 0)
                    icon: "schedule"
                    accessibleName: Tr.tr("Queue this message for after the current turn")
                    onClicked: root.queueComposer()
                }

                IconButton {
                    icon: AssistantSettings.speakReplies ? "volume_up" : "volume_off"
                    accessibleName: AssistantSettings.speakReplies ? Tr.tr("Disable spoken replies") : Tr.tr("Speak replies")
                    onClicked: AssistantSettings.speakReplies = !AssistantSettings.speakReplies
                }

                IconTextButton {
                    icon: Assistant.streaming ? "stop" : "send"
                    text: Assistant.streaming ? Tr.tr("Stop") : Tr.tr("Send")
                    enabled: Assistant.streaming || (Assistant.ready && !Assistant.sessionOwned && (composer.text.trim().length > 0 || root.attachmentPaths.length > 0))
                    onClicked: Assistant.streaming ? Assistant.cancel() : root.submitComposer()
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
