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

    // Text and controls scale independently; Alt+=/Alt+- and Alt+Shift+=/Alt+Shift+-.
    readonly property real fontScale: AssistantSettings.textScale
    readonly property real uiScale: AssistantSettings.uiScale
    property int historyIndex: -1
    property string historyDraft: ""
    property var queuedMessages: []
    property var attachmentPaths: []
    property bool activityExpanded: false
    property bool showArchived: false
    property bool dropActive: false
    property string renameTargetId: ""
    property bool sidebarOpen: false
    property bool sessionPickerOpen: false
    property int sessionPickIndex: 0
    property string sessionPickId: ""

    onSessionPickIndexChanged: {
        if (sessionsList && sessionsList.currentIndex !== sessionPickIndex)
            sessionsList.currentIndex = sessionPickIndex;
    }
    onPickerSessionsChanged: {
        root.syncSessionPick(false);
    }
    property var openTabs: []
    property string maintenanceSessionId: ""
    readonly property real sidebarWidth: {
        const total = root.width > 0 ? root.width : root.implicitWidth;
        return Math.min(total, Math.min(300, Math.max(220, total * 0.36)));
    }

    readonly property var pickerSessions: {
        Assistant.pinned;
        const query = sessionSearch.text.trim().toLowerCase();
        const visible = Assistant.sessions.filter(session => root.showArchived || !Assistant.isArchived(session.id));
        const filtered = query.length === 0 ? visible : visible.filter(session => String(Assistant.sessionTitleFor(session.id, session.title)).toLowerCase().includes(query));
        return filtered.slice().sort((a, b) => Number(Assistant.isPinned(b.id)) - Number(Assistant.isPinned(a.id)));
    }

    function toggleSidebar(): void {
        root.sidebarOpen = !root.sidebarOpen;
    }

    function syncSessionPick(preferCurrent: bool): void {
        const count = root.pickerSessions.length;
        if (count === 0) {
            root.sessionPickIndex = 0;
            root.sessionPickId = "";
            return;
        }
        let index = root.pickerSessions.findIndex(session => session.id === root.sessionPickId);
        if (index < 0 && preferCurrent)
            index = root.pickerSessions.findIndex(session => session.id === Assistant.sessionId);
        if (index < 0)
            index = 0;
        root.sessionPickIndex = index;
        root.sessionPickId = root.pickerSessions[index].id;
        if (sessionsList) {
            sessionsList.currentIndex = index;
            sessionsList.positionViewAtIndex(index, ListView.Contain);
        }
    }

    function resetSessionPick(): void {
        root.syncSessionPick(false);
    }

    function moveSessionPick(delta: int): void {
        const count = root.pickerSessions.length;
        if (count === 0)
            return;
        const next = Math.max(0, Math.min(count - 1, root.sessionPickIndex + delta));
        root.sessionPickIndex = next;
        root.sessionPickId = root.pickerSessions[next].id;
        sessionsList.currentIndex = next;
        sessionsList.positionViewAtIndex(next, ListView.Contain);
    }

    function chooseSessionPick(index: int): void {
        const session = root.pickerSessions[index];
        if (!session)
            return;
        root.sessionPickIndex = index;
        root.sessionPickId = session.id;
        Assistant.selectSession(session.id);
        sessionsPopup.close();
    }

    function chooseCurrentSessionPick(): void {
        root.chooseSessionPick(root.sessionPickIndex);
    }

    function statusText(): string {
        if (!Assistant.configured)
            return Tr.tr("DeepSeek Harness is not ready");
        const parts = [Assistant.modelLabel];
        if (Assistant.reasoningEffort.length > 0)
            parts.push(Tr.tr("thinking %1").arg(Assistant.reasoningEffort));
        parts.push(Tr.tr("ctx %1%").arg(Math.round(Assistant.contextRatio * 100)));
        if (Assistant.cachePercent >= 0)
            parts.push(Assistant.cacheLabel);
        parts.push(Assistant.streaming ? Tr.tr("working") : Tr.tr("idle"));
        if (root.viewingAgent)
            parts.push(Tr.tr("read-only"));
        else if (Assistant.sessionOwned)
            parts.push(Tr.tr("owned by dsh-tui"));
        return parts.join(" · ");
    }

    function adjustUiScale(delta: real): void {
        AssistantSettings.uiScale = Math.round(Math.max(0.72, Math.min(1.15, AssistantSettings.uiScale + delta)) * 100) / 100;
    }

    function adjustTextScale(delta: real): void {
        AssistantSettings.textScale = Math.round(Math.max(0.75, Math.min(1.25, AssistantSettings.textScale + delta)) * 100) / 100;
    }

    function focusSessionSearch(): void {
        root.sidebarOpen = true;
        Qt.callLater(() => sidebar.focusSearch());
    }

    function pickerMatches(): var {
        const query = pickerSearch.text.trim().toLowerCase();
        const visible = Assistant.sessions.filter(session => root.showArchived || !Assistant.isArchived(session.id));
        const filtered = query.length === 0 ? visible : visible.filter(session => String(Assistant.sessionTitleFor(session.id, session.title)).toLowerCase().includes(query));
        return filtered.slice().sort((a, b) => Number(Assistant.isPinned(b.id)) - Number(Assistant.isPinned(a.id)));
    }

    function submitPickerSearch(): void {
        const matches = root.pickerMatches();
        if (matches.length !== 1)
            return;
        Assistant.selectSession(matches[0].id);
        root.sessionPickerOpen = false;
    }

    function selectRelativeSession(delta: int): void {
        const ids = sidebar.visibleIds;
        if (ids.length === 0)
            return;
        let index = ids.indexOf(Assistant.sessionId);
        if (index < 0)
            index = delta > 0 ? -1 : 0;
        const next = Math.max(0, Math.min(ids.length - 1, index + delta));
        Assistant.selectSession(ids[next]);
    }

    function selectSessionAt(index: int): void {
        const ids = sidebar.visibleIds;
        if (index >= 0 && index < ids.length)
            Assistant.selectSession(ids[index]);
    }

    function selectAgentAt(index: int): void {
        if (index === 0) {
            Assistant.viewHome();
            return;
        }
        const agent = Assistant.agentSessions[index - 1];
        if (agent)
            Assistant.viewAgent(agent.id);
    }

    function cycleAgent(delta: int): void {
        const count = 1 + Assistant.agentSessions.length;
        if (count <= 1) {
            Assistant.viewHome();
            return;
        }
        const index = Assistant.agentSessions.findIndex(agent => agent.id === Assistant.sessionId);
        const current = Assistant.viewingAgent && index >= 0 ? index + 1 : 0;
        root.selectAgentAt((current + delta + count) % count);
    }

    function ensureTab(id: string, title: string, persistent: bool): void {
        if (!id)
            return;
        const index = root.openTabs.findIndex(tab => tab.id === id);
        if (index >= 0) {
            const current = root.openTabs[index];
            const nextTitle = title || current.title;
            const nextPersistent = persistent || current.persistent;
            if (nextTitle === current.title && nextPersistent === current.persistent)
                return;
            const next = root.openTabs.slice();
            next[index] = Object.assign({}, current, { title: nextTitle, persistent: nextPersistent });
            root.openTabs = next;
            return;
        }
        const entry = { id, title: title || Tr.tr("New chat"), persistent: persistent };
        root.openTabs = persistent ? [entry].concat(root.openTabs) : root.openTabs.concat([entry]);
    }

    function updateTabTitle(id: string, title: string): void {
        const index = root.openTabs.findIndex(tab => tab.id === id);
        if (index < 0 || !title || root.openTabs[index].title === title)
            return;
        const next = root.openTabs.slice();
        next[index] = Object.assign({}, next[index], { title });
        root.openTabs = next;
    }

    function seedTabs(): void {
        root.maintenanceSessionId = Assistant.defaultSessionId;
        for (const session of Assistant.sessions) {
            const tab = root.openTabs.find(item => item.id === session.id);
            if (tab)
                root.updateTabTitle(session.id, Assistant.sessionTitleFor(session.id, session.title));
        }
        if (root.maintenanceSessionId.length > 0)
            root.ensureTab(root.maintenanceSessionId, Tr.tr("Padilha"), true);
        if (Assistant.sessionId.length > 0)
            root.ensureTab(Assistant.sessionId, Assistant.sessionTitle || Tr.tr("Chat"), Assistant.sessionId === root.maintenanceSessionId);
    }

    function activateTab(id: string): void {
        if (!id || Assistant.streaming || id === Assistant.sessionId)
            return;
        Assistant.selectSession(id);
    }

    function closeTab(id: string): void {
        if (Assistant.streaming)
            return;
        const index = root.openTabs.findIndex(tab => tab.id === id);
        if (index < 0 || root.openTabs[index].persistent)
            return;
        const next = root.openTabs.slice();
        next.splice(index, 1);
        root.openTabs = next;
        if (id !== Assistant.sessionId)
            return;
        const fallback = next[Math.max(0, Math.min(index - 1, next.length - 1))];
        if (fallback)
            Assistant.selectSession(fallback.id);
        else
            Assistant.newChat();
    }

    function closeCurrentTab(): void {
        root.closeTab(Assistant.sessionId);
    }

    function cycleTab(delta: int): void {
        if (root.openTabs.length < 2)
            return;
        const index = root.openTabs.findIndex(tab => tab.id === Assistant.sessionId);
        const start = index < 0 ? 0 : index;
        const next = root.openTabs[(start + delta + root.openTabs.length) % root.openTabs.length];
        root.activateTab(next.id);
    }

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
        root.seedTabs();
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
        if (!Assistant.ready || Assistant.sessionOwned || root.viewingAgent)
            return;
        Assistant.send(text, root.attachmentPaths.slice());
        composer.text = "";
        root.attachmentPaths = [];
        root.resetHistory();
    }

    function answerQuestion(answer: string): void {
        if (Assistant.streaming || answer.length === 0)
            return;
        Assistant.send(answer);
        root.resetHistory();
    }

    function queueComposer(): void {
        if (root.viewingAgent)
            return;
        const text = composer.text.trim();
        if (text.length === 0 && root.attachmentPaths.length === 0)
            return;
        const next = root.queuedMessages.slice();
        next.push({ text: text, attachments: root.attachmentPaths.slice() });
        root.queuedMessages = next;
        composer.text = "";
        root.attachmentPaths = [];
        root.resetHistory();
    }

    function queuedLabel(): string {
        const count = root.queuedMessages.length;
        if (count === 0)
            return "";
        const last = root.queuedMessages[count - 1];
        return Tr.tr("%1 na fila · %2").arg(count).arg(last.text || Tr.tr("anexo"));
    }

    function sendQueued(): void {
        if (root.queuedMessages.length === 0 || Assistant.streaming || !Assistant.ready || Assistant.sessionOwned || root.viewingAgent)
            return;
        const next = root.queuedMessages.slice();
        const item = next.shift();
        root.queuedMessages = next;
        Assistant.send(item.text || "", item.attachments || []);
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

    function recoverStuckTurn(): void {
        if (!Assistant.streaming)
            return;
        root.error = Tr.tr("DSH stopped responding; the turn was cancelled.");
        Assistant.cancel();
        root.focusComposer();
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
        } else if (Assistant.draft.length > 0) {
            composer.text = Assistant.draft;
            composer.cursorPosition = composer.text.length;
        }
        root.focusComposer();
    }
    Component.onDestruction: {
        Assistant.stop();
    }

    function focusComposer(): void {
        if (root.screenState.assistant && Assistant.ready && !Assistant.streaming)
            Qt.callLater(() => composer.forceActiveFocus());
    }

    Connections {
        function onReadyChanged(): void {
            root.focusComposer();
            root.seedTabs();
        }

        function onStreamingChanged(): void {
            if (Assistant.streaming)
                streamWatchdog.restart();
            else
                streamWatchdog.stop();
            if (Assistant.streaming)
                return;
            root.focusComposer();
            if (Assistant.lastStop === "complete" && root.queuedMessages.length > 0)
                Qt.callLater(() => root.sendQueued());
        }

        // Follow the conversation only while the user is at the bottom. Once
        // they scroll up to read history, new turns must not yank them down.
        function onMessagesChanged(): void {
            if (Assistant.streaming)
                streamWatchdog.restart();
        }

        function onActivityChanged(): void {
            if (Assistant.streaming)
                streamWatchdog.restart();
        }

        function onPendingQuestionChanged(): void {
            if (Assistant.pendingQuestion.length > 0 && root.screenState.assistant)
                Qt.callLater(() => composer.forceActiveFocus());
        }

        function onSessionIdChanged(): void {
            root.resetHistory();
            root.queuedMessages = [];
            root.attachmentPaths = [];
            root.activityExpanded = false;
            transcript.follow = true;
            transcript.scheduleFollow();
            if (Assistant.sessionId.length > 0)
                root.ensureTab(Assistant.sessionId, Assistant.sessionTitle || Tr.tr("Chat"), Assistant.sessionId === root.maintenanceSessionId);
        }

        function onSessionTitleChanged(): void {
            root.updateTabTitle(Assistant.sessionId, Assistant.sessionTitle);
        }

        function onSessionsChanged(): void {
            root.seedTabs();
        }

        function onSessionsRequested(): void {
            Assistant.refreshAgents();
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

    Timer {
        id: streamWatchdog

        interval: 60000
        repeat: false
        running: Assistant.streaming
        onTriggered: root.recoverStuckTurn()
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

                    scale: root.uiScale
                    icon: "close"
                    text: Tr.tr("Cancel")
                    onClicked: renamePopup.close()
                }

                IconTextButton {

                    scale: root.uiScale
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
        id: chatColumn

        anchors.fill: parent
        anchors.leftMargin: root.sidebarOpen ? root.sidebarWidth + Tokens.spacing.small : 0
        spacing: Tokens.spacing.medium

        StyledRect {
            id: chatPanel

            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.large
            color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                AgentTabs {
                    id: agentTabs

                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.maximumHeight: implicitHeight
                    uiScale: root.uiScale
                    agents: Assistant.agentSessions
                    extraTabs: root.openTabs
                    homeId: Assistant.defaultSessionId
                    activeId: Assistant.sessionId
                    activeTitle: Assistant.sessionTitle || Assistant.sessionLabel
                    viewingAgent: Assistant.viewingAgent

                    onHomeRequested: Assistant.viewHome()
                    onAgentRequested: function (id) {
                        if (Assistant.agentSessions.some(agent => agent.id === id))
                            Assistant.viewAgent(id);
                        else
                            Assistant.selectSession(id);
                    }
                    onCloseRequested: function (id) {
                        if (id === Assistant.defaultSessionId)
                            root.screenState.assistant = false;
                    }
                    onSessionCloseRequested: function (id) {
                        const index = root.openTabs.findIndex(tab => tab.id === id);
                        if (index < 0)
                            return;
                        const next = root.openTabs.slice();
                        next.splice(index, 1);
                        root.openTabs = next;
                        if (Assistant.sessionId === id)
                            Assistant.viewHome();
                    }
                }

                IconButton {

                    scale: root.uiScale
                    id: historyButton

                    visible: false
                    icon: "history"
                    accessibleName: Tr.tr("DSH sessions")
                    onClicked: sessionsPopup.open()
                }

                IconButton {

                    scale: root.uiScale
                    id: sessionButton

                    icon: "add_comment"
                    accessibleName: Tr.tr("New or resume DSH session")
                    onClicked: sessionsPopup.opened ? sessionsPopup.close() : sessionsPopup.open()
                }
            }


            Popup {
                id: sessionsPopup

                parent: root
                x: Math.max(8, root.width - width - 8)
                y: 56
                width: Math.min(460, root.width - 16)
                height: Math.min(520, root.height - 64)
                padding: 8
                modal: false
                focus: true
                closePolicy: Popup.CloseOnEscape
                onOpened: {
                    sessionSearch.text = "";
                    root.sessionPickId = Assistant.sessionId;
                    root.syncSessionPick(true);
                    Qt.callLater(() => sessionSearch.forceActiveFocus());
                }

                background: StyledRect {
                    radius: Tokens.rounding.medium
                    color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 1)
                }

                contentItem: ColumnLayout {
                    spacing: Tokens.spacing.extraSmall

                    IconTextButton {

                        scale: root.uiScale
                        Layout.fillWidth: true
                        icon: "add"
                        text: Tr.tr("New session")
                        onClicked: {
                            Assistant.newChat();
                            sessionsPopup.close();
                        }
                    }

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
                            color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 1)
                        }

                        onTextChanged: root.resetSessionPick()
                        onAccepted: root.chooseCurrentSessionPick()

                        Keys.onPressed: event => {
                            const plain = !(event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
                            const vim = (event.modifiers & (Qt.AltModifier | Qt.ControlModifier)) !== 0;
                            if (event.key === Qt.Key_Up && plain) {
                                root.moveSessionPick(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down && plain) {
                                root.moveSessionPick(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.chooseCurrentSessionPick();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_J && vim) {
                                root.moveSessionPick(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_K && vim) {
                                root.moveSessionPick(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                sessionsPopup.close();
                                event.accepted = true;
                            }
                        }
                    }

                    ListView {
                    id: sessionsList

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.pickerSessions
                    currentIndex: root.sessionPickIndex
                    onCurrentIndexChanged: {
                        if (currentIndex !== root.sessionPickIndex)
                            root.sessionPickIndex = currentIndex;
                    }
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: ItemDelegate {
                        id: sessionDelegate

                        required property var modelData
                        required property int index
                        readonly property bool selected: index === root.sessionPickIndex

                        width: sessionsList.width
                        height: 56
                        padding: 0
                        onClicked: {
                            root.sessionPickIndex = index;
                            root.sessionPickId = modelData.id;
                            Assistant.selectSession(modelData.id);
                            sessionsPopup.close();
                        }

                        background: StyledRect {
                            radius: Tokens.rounding.small
                            color: sessionDelegate.selected ? Colours.palette.m3primaryContainer : (sessionDelegate.hovered ? Qt.alpha(Colours.palette.m3surfaceContainerHighest, 1) : "transparent")
                            border.width: sessionDelegate.selected ? 2 : 0
                            border.color: Colours.palette.m3primary
                        }

                        contentItem: StyledText {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.small
                            anchors.rightMargin: 128
                            verticalAlignment: Text.AlignVCenter
                            text: Assistant.sessionTitleFor(sessionDelegate.modelData.id, sessionDelegate.modelData.title) + (sessionDelegate.modelData.owned ? " · live" : "")
                            elide: Text.ElideRight
                            font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                            color: sessionDelegate.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                        }

                        RowLayout {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            IconButton {

                                scale: root.uiScale
                                icon: "edit"
                                accessibleName: Tr.tr("Rename session")
                                onClicked: root.openRename(sessionDelegate.modelData.id, Assistant.sessionTitleFor(sessionDelegate.modelData.id, sessionDelegate.modelData.title))
                            }

                            IconButton {

                                scale: root.uiScale
                                icon: Assistant.isArchived(sessionDelegate.modelData.id) ? "unarchive" : "archive"
                                accessibleName: Assistant.isArchived(sessionDelegate.modelData.id) ? Tr.tr("Unarchive session") : Tr.tr("Archive session")
                                onClicked: Assistant.toggleArchived(sessionDelegate.modelData.id)
                            }

                            IconButton {

                                scale: root.uiScale
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

                        scale: root.uiScale
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

            Transcript {
                id: transcript
                objectName: "transcript"

                Layout.fillWidth: true
                Layout.fillHeight: true
                messages: Assistant.messages
                fontScale: root.fontScale

                onCopyRequested: text => root.copyMessage(text)
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

                                scale: root.uiScale
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
                visible: root.queuedMessages.length > 0
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "schedule"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.queuedLabel()
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                    elide: Text.ElideRight
                }

                IconButton {

                    scale: root.uiScale
                    visible: !Assistant.streaming
                    icon: "send"
                    accessibleName: Tr.tr("Send queued message")
                    onClicked: root.sendQueued()
                }

                IconButton {

                    scale: root.uiScale
                    icon: "close"
                    accessibleName: Tr.tr("Discard queued message")
                    onClicked: root.queuedMessages = []
                }
            }

            StyledRect {
                visible: Assistant.pendingQuestion.length > 0
                Layout.fillWidth: true
                implicitHeight: questionColumn.implicitHeight + Tokens.padding.small * 2
                radius: Tokens.rounding.medium
                color: Colours.palette.m3secondaryContainer
                border.width: 1
                border.color: Colours.palette.m3primary

                ColumnLayout {
                    id: questionColumn

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Pergunta do agente")
                        color: Colours.palette.m3onSecondaryContainer
                        font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Assistant.pendingQuestion
                        color: Colours.palette.m3onSecondaryContainer
                        font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: Assistant.pendingQuestionOptions

                        delegate: IconTextButton {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            scale: root.uiScale
                            type: IconTextButton.Tonal
                            icon: "arrow_right"
                            text: modelData.id + ". " + modelData.label
                            enabled: !Assistant.streaming
                            onClicked: root.answerQuestion(modelData.id)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(composer.implicitHeight, 40 * root.uiScale) + Tokens.padding.medium * 2 * root.uiScale
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainerHigh
                    border.width: root.dropActive ? 2 : 0
                    border.color: Colours.palette.m3primary

                    TextArea {
                        id: composer

                        objectName: "assistantComposer"
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        wrapMode: TextArea.Wrap
                        placeholderText: Assistant.pendingQuestion.length > 0 ? Tr.tr("Responda para retomar o agente") : (VoiceInput.dictating ? Tr.tr("Listening… speak now") : (root.viewingAgent ? Tr.tr("Agent session — read-only") : (Assistant.sessionOwned ? Tr.tr("Read-only session — start a new chat") : (Assistant.streaming ? Tr.tr("Type while the assistant works — Enter queues") : Tr.tr("Ask the assistant")))))
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.builders.medium.scale(root.fontScale).build()
                        background: null
                        // Keep the draft editable while the answer streams;
                        // Enter waits for the current turn to finish instead of
                        // sending a second prompt into an active turn.
                        enabled: Assistant.ready && !Assistant.sessionOwned && !root.viewingAgent
                        onTextChanged: Assistant.draft = text

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

                    scale: root.uiScale
                    icon: "attach_file"
                    accessibleName: Tr.tr("Attach images")
                    enabled: !Assistant.sessionOwned && !root.viewingAgent
                    onClicked: attachmentDialog.open()
                }

                Item {
                    implicitWidth: micButton.implicitWidth
                    implicitHeight: micButton.implicitHeight

                    IconButton {

                        scale: root.uiScale
                        id: micButton

                        icon: VoiceInput.dictating ? "stop_circle" : (AssistantSettings.wakeEnabled ? "graphic_eq" : "mic")
                        accessibleName: VoiceInput.dictating ? Tr.tr("Stop dictation") : (AssistantSettings.wakeEnabled ? Tr.tr("Disable wake mode") : Tr.tr("Dictate a message"))
                        enabled: Assistant.ready && !Assistant.sessionOwned && !root.viewingAgent
                        onClicked: VoiceInput.dictate()
                    }

                    StyledRect {
                        visible: AssistantSettings.wakeEnabled
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 3
                        implicitWidth: 7
                        implicitHeight: 7
                        radius: 3.5
                        color: Colours.palette.m3primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        enabled: micButton.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AssistantSettings.wakeEnabled = !AssistantSettings.wakeEnabled
                    }
                }

                IconButton {

                    scale: root.uiScale
                    visible: Assistant.streaming && (composer.text.trim().length > 0 || root.attachmentPaths.length > 0)
                    icon: "schedule"
                    accessibleName: Tr.tr("Queue this message for after the current turn")
                    onClicked: root.queueComposer()
                }

                IconButton {

                    scale: root.uiScale
                    icon: AssistantSettings.speakReplies ? "volume_up" : "volume_off"
                    accessibleName: AssistantSettings.speakReplies ? Tr.tr("Disable spoken replies") : Tr.tr("Speak replies")
                    onClicked: AssistantSettings.speakReplies = !AssistantSettings.speakReplies
                }

                IconTextButton {

                    scale: root.uiScale
                    icon: Assistant.streaming ? "stop" : "send"
                    text: Assistant.streaming ? Tr.tr("Stop") : Tr.tr("Send")
                    enabled: Assistant.streaming || (Assistant.ready && !Assistant.sessionOwned && !root.viewingAgent && (composer.text.trim().length > 0 || root.attachmentPaths.length > 0))
                    onClicked: Assistant.streaming ? Assistant.cancel() : root.submitComposer()
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 2
                radius: 1
                clip: true
                visible: Assistant.ready
                color: Colours.tPalette.m3surfaceContainerHighest

                Accessible.role: Accessible.ProgressBar
                Accessible.name: Assistant.contextLabel

                StyledRect {
                    width: parent.width * Assistant.contextRatio
                    height: parent.height
                    radius: 1
                    color: Assistant.contextRatio >= 0.9 ? Colours.palette.m3error : Colours.palette.m3primary

                    Behavior on width {
                        Anim {}
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.statusText()
                font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
                objectName: "assistantStatus"
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

    // The session picker is a page inside the panel, not a floating popup.
    Item {
        id: sessionsPage

        anchors.fill: parent
        z: 30
        visible: root.sessionPickerOpen

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: Qt.alpha(Colours.palette.m3surface, 1)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Sessions")
                    font: Tokens.font.title.builders.medium.scale(root.fontScale).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                IconButton {

                    scale: root.uiScale
                    icon: "add"
                    accessibleName: Tr.tr("New session")
                    onClicked: {
                        Assistant.newChat();
                        root.sessionPickerOpen = false;
                    }
                }

                IconButton {

                    scale: root.uiScale
                    icon: "close"
                    accessibleName: Tr.tr("Close session picker")
                    onClicked: root.sessionPickerOpen = false
                }
            }

            TextField {
                id: pickerSearch

                Layout.fillWidth: true
                placeholderText: Tr.tr("Search sessions")
                color: Colours.palette.m3onSurface
                placeholderTextColor: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                onAccepted: root.submitPickerSearch()
                Keys.onReturnPressed: root.submitPickerSearch()
                Keys.onEnterPressed: root.submitPickerSearch()
                background: StyledRect {
                    radius: Tokens.rounding.small
                    color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 1)
                }
            }

            ListView {
                id: pickerList

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.pickerMatches()

                delegate: ItemDelegate {
                    id: pickerRow

                    required property var modelData

                    width: pickerList.width
                    height: 62
                    padding: 0
                    onClicked: {
                        Assistant.selectSession(modelData.id);
                        root.sessionPickerOpen = false;
                    }

                    background: StyledRect {
                        radius: Tokens.rounding.small
                        color: pickerRow.hovered ? Qt.alpha(Colours.palette.m3surfaceContainerHighest, 1) : "transparent"
                    }

                    contentItem: ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.small
                        anchors.rightMargin: Tokens.padding.small
                        anchors.topMargin: Tokens.padding.extraSmall
                        anchors.bottomMargin: Tokens.padding.extraSmall
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: Assistant.sessionTitleFor(pickerRow.modelData.id, pickerRow.modelData.title) + (pickerRow.modelData.owned ? " · live" : "")
                            elide: Text.ElideRight
                            font: Tokens.font.body.builders.medium.scale(root.fontScale).build()
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Qt.formatDateTime(new Date(pickerRow.modelData.updated), "dd/MM HH:mm")
                            elide: Text.ElideRight
                            font: Tokens.font.label.builders.small.scale(root.fontScale).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }
        }

        onVisibleChanged: {
            if (visible) {
                pickerSearch.text = "";
                Qt.callLater(() => pickerSearch.forceActiveFocus());
            }
        }
    }

    Timer {
        interval: (Assistant.agentSessions.length > 0 || Assistant.viewingAgent) ? 2000 : 4000
        running: Assistant.ready
        repeat: true
        onTriggered: Assistant.refreshAgents()
    }

    Timer {
        interval: 2000
        running: Assistant.viewingAgent
        repeat: true
        onTriggered: Assistant.reloadCurrent()
    }

    // The full session sidebar is archived; AgentTabs is the only session UI.
    Item {
        id: sidebar

        visible: false
        readonly property var visibleIds: []

        function focusSearch(): void {}
    }

    Shortcut {
        sequence: "Alt+N"
        onActivated: Assistant.newChat()
    }

    Shortcut {
        sequence: "Alt+L"
        onActivated: root.focusComposer()
    }

    Shortcut {
        sequence: "Alt+1"
        onActivated: root.selectAgentAt(0)
    }

    Shortcut {
        sequence: "Alt+2"
        onActivated: root.selectAgentAt(1)
    }

    Shortcut {
        sequence: "Alt+3"
        onActivated: root.selectAgentAt(2)
    }

    Shortcut {
        sequence: "Alt+4"
        onActivated: root.selectAgentAt(3)
    }

    Shortcut {
        sequence: "Alt+5"
        onActivated: root.selectAgentAt(4)
    }

    Shortcut {
        sequence: "Alt+6"
        onActivated: root.selectAgentAt(5)
    }

    Shortcut {
        sequence: "Alt+7"
        onActivated: root.selectAgentAt(6)
    }

    Shortcut {
        sequence: "Alt+8"
        onActivated: root.selectAgentAt(7)
    }

    Shortcut {
        sequence: "Alt+9"
        onActivated: root.selectAgentAt(8)
    }

    Shortcut {
        sequence: "Alt+Left"
        onActivated: root.cycleAgent(-1)
    }

    Shortcut {
        sequence: "Alt+Right"
        onActivated: root.cycleAgent(1)
    }

    Shortcut {
        sequence: "Alt+="
        onActivated: root.adjustUiScale(0.04)
    }

    Shortcut {
        sequence: "Alt+Shift+="
        onActivated: root.adjustUiScale(0.04)
    }

    Shortcut {
        sequence: "Alt+-"
        onActivated: root.adjustUiScale(-0.04)
    }

    Shortcut {
        sequence: "Alt+Shift+-"
        onActivated: root.adjustUiScale(-0.04)
    }

    Shortcut {
        sequence: "Alt+Ctrl+="
        onActivated: root.adjustTextScale(0.04)
    }

    Shortcut {
        sequence: "Alt+Ctrl+-"
        onActivated: root.adjustTextScale(-0.04)
    }

    Keys.onEscapePressed: Assistant.cancelOrClose()
}
