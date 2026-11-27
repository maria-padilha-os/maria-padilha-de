pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n
import qs.services

Singleton {
    id: root

    property bool ready: false
    property bool streaming: false
    property string error: ""
    property string activity: ""
    property var activityLog: []
    property string lastStop: ""
    property string selectedModel: ""
    property list<var> models: []
    property list<var> roots: []
    property list<var> sessions: []
    property list<var> agentSessions: []
    property string defaultSessionId: ""
    property bool viewingAgent: false
    property string sessionId: ""
    property string sessionTitle: ""
    property bool sessionOwned: false
    property list<var> messages: []
    property int nextId: 1
    property int activeId: -1
    property bool started: false
    property bool stopping: false
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/padilha"
    readonly property string pinsPath: configDir + "/dsh-pinned.json"
    readonly property string aliasesPath: configDir + "/dsh-session-aliases.json"
    readonly property string archivedPath: configDir + "/dsh-session-archived.json"
    property var pinned: []
    property var aliases: ({})
    property var archived: []

    signal sessionsRequested()
    signal closeRequested()

    readonly property bool configured: models.length > 0
    readonly property string rootsLabel: roots.length === 0 ? Tr.tr("No folders granted") : Tr.trN("%n folder granted", "%n folders granted", roots.length)
    readonly property string sessionLabel: {
        const alias = root.aliases[root.sessionId];
        if (typeof alias === "string" && alias.length > 0)
            return alias;
        return sessionTitle.length > 0 ? sessionTitle : Tr.tr("No DSH session");
    }
    readonly property string modelLabel: {
        const model = models.find(m => m.id === selectedModel);
        return model ? model.name : Tr.tr("DeepSeek Harness");
    }
    readonly property bool speakReplies: AssistantSettings.speakReplies
    // DSH records provider usage and the route's context window. Until the
    // first turn reports them, fall back to the visible-transcript estimate.
    property int contextTokens: 0
    property int contextWindow: 0
    readonly property int contextLimit: {
        if (root.contextWindow > 0)
            return root.contextWindow;
        const value = Number(Quickshell.env("PADILHA_DSH_CONTEXT_LIMIT") || 128000);
        return Number.isFinite(value) && value > 0 ? value : 128000;
    }
    readonly property int estimatedContextTokens: {
        if (root.contextTokens > 0)
            return root.contextTokens;
        let chars = 0;
        for (const message of root.messages)
            chars += String(message.text || "").length;
        return Math.ceil(chars / 4);
    }
    readonly property real contextRatio: Math.max(0, Math.min(1, root.estimatedContextTokens / root.contextLimit))
    readonly property string contextLabel: Tr.tr("Estimated context: %1%").arg(Math.round(root.contextRatio * 100))

    function handle(line: string): void {
        let event;
        try {
            event = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (!event || typeof event !== "object")
            return;

        switch (event.type) {
        case "ready":
            root.ready = true;
            // A backend can finish starting while the user has already sent
            // into the restored session. Never replace that in-flight message
            // list with a late default history snapshot.
            if (root.streaming)
                break;
            root.activity = "";
            root.activityLog = [];
            root.lastStop = "";
            root.models = event.models || [];
            root.roots = event.roots || [];
            root.selectedModel = root.selectedModel || (root.models[0]?.id ?? "");
            root.sessions = event.sessions || [];
            root.defaultSessionId = event.defaultSessionId || event.sessionId || "";
            root.refreshAgents();
            root.sessionId = event.sessionId || "";
            root.sessionTitle = event.sessionTitle || "";
            root.sessionOwned = !!event.sessionOwned;
            root.contextTokens = Number(event.context?.tokens || 0);
            root.contextWindow = Number(event.context?.window || 0);
            root.setHistory(event.history, true);
            const savedSession = AssistantSettings.lastSessionId;
            if (savedSession.length > 0 && savedSession !== root.sessionId && root.sessions.some(session => session.id === savedSession)) {
                root.viewingAgent = savedSession !== root.defaultSessionId;
                Qt.callLater(() => root.selectSession(savedSession));
            }
            root.error = "";
            break;
        case "sessions":
            root.sessions = event.sessions || [];
            break;
        case "subagents":
            root.handleSubagents(event.agents || []);
            break;
        case "history":
            // A session load can be slower than the user's next prompt. Its
            // snapshot must not wipe the user message that is already streaming.
            if (root.streaming)
                break;
            root.activity = "";
            root.activityLog = [];
            root.lastStop = "";
            root.sessionId = event.sessionId || root.sessionId;
            root.sessionTitle = event.sessionTitle || "";
            root.sessionOwned = !!event.sessionOwned;
            root.messages = [];
            root.contextTokens = Number(event.context?.tokens || 0);
            root.contextWindow = Number(event.context?.window || 0);
            root.setHistory(event.history, true);
            root.streaming = false;
            root.activeId = -1;
            break;
        case "new":
            root.activity = "";
            root.activityLog = [];
            root.lastStop = "";
            root.sessionId = event.sessionId || "";
            if (root.sessionId.length > 0)
                AssistantSettings.lastSessionId = root.sessionId;
            root.sessionTitle = "";
            root.sessionOwned = false;
            root.messages = [];
            root.contextTokens = 0;
            root.contextWindow = 0;
            root.error = "";
            break;
        case "session":
            root.sessionId = event.sessionId || root.sessionId;
            if (root.sessionId.length > 0)
                AssistantSettings.lastSessionId = root.sessionId;
            root.sessionTitle = event.sessionTitle || root.sessionTitle;
            root.sessionOwned = !!event.sessionOwned;
            if (root.sessionTitle.length > 0 && root.sessionId.length > 0) {
                const current = { id: root.sessionId, title: root.sessionTitle, updated: Date.now(), owned: root.sessionOwned };
                const index = root.sessions.findIndex(s => s.id === root.sessionId);
                const next = root.sessions.slice();
                if (index >= 0)
                    next[index] = Object.assign({}, next[index], current);
                else
                    next.unshift(current);
                root.sessions = next;
            }
            break;
        case "usage":
            root.contextTokens = Number(event.usage?.inputTokens || 0) + Number(event.usage?.cacheReadTokens || 0) + Number(event.usage?.cacheWriteTokens || 0);
            if (Number(event.contextWindow || 0) > 0)
                root.contextWindow = Number(event.contextWindow);
            break;
        case "context":
            if (Number(event.contextWindow || 0) > 0)
                root.contextWindow = Number(event.contextWindow);
            break;
        case "activity":
            if (event.id === root.activeId) {
                const text = event.text || "";
                root.activity = text;
                if (text.length > 0 && root.activityLog[root.activityLog.length - 1] !== text) {
                    const log = root.activityLog.slice();
                    log.push(text);
                    if (log.length > 30)
                        log.shift();
                    root.activityLog = log;
                }
            }
            break;
        case "assistant": {
            if (event.id !== root.activeId)
                return;
            const index = root.messages.findIndex(m => m.id === event.id);
            if (index >= 0) {
                const next = root.messages.slice();
                next[index] = Object.assign({}, next[index], {
                    text: event.text || "",
                    streaming: true,
                });
                root.messages = next;
            }
            root.activity = Tr.tr("Writing the answer…");
            break;
        }
        case "done": {
            if (event.id !== root.activeId)
                return;
            const index = root.messages.findIndex(m => m.id === event.id);
            if (index >= 0) {
                const next = root.messages.slice();
                next[index] = Object.assign({}, next[index], {
                    text: event.text || next[index].text || "",
                    streaming: false,
                    cancelled: event.stop === "cancelled",
                });
                root.messages = next;
            }
            root.lastStop = event.stop || "complete";
            root.streaming = false;
            root.activeId = -1;
            root.activity = "";
            root.refreshSessions();
            root.refreshAgents();
            if (root.speakReplies && (event.text || "").trim().length > 0)
                Quickshell.execDetached(["padilha-voice", "speak", "--", event.text]);
            break;
        }
        case "error": {
            if (event.id !== undefined && event.id !== root.activeId)
                return;
            root.error = event.message || Tr.tr("DSH request failed");
            const index = root.messages.findIndex(m => m.id === root.activeId);
            if (index >= 0) {
                const next = root.messages.slice();
                next[index] = Object.assign({}, next[index], {
                    text: root.error,
                    streaming: false,
                    error: true,
                });
                root.messages = next;
            }
            root.lastStop = "error";
            root.streaming = false;
            root.activeId = -1;
            root.activity = "";
            break;
        }
        }
    }

    function isPinned(id: string): bool {
        return root.pinned.indexOf(id) !== -1;
    }

    function isArchived(id: string): bool {
        return root.archived.indexOf(id) !== -1;
    }

    function sessionTitleFor(id: string, fallback: string): string {
        const alias = root.aliases[id];
        if (typeof alias === "string" && alias.length > 0)
            return alias;
        return fallback || "";
    }

    function loadSessionMeta(): void {
        try {
            const parsed = JSON.parse(aliasesFile.text());
            root.aliases = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : ({});
        } catch (e) {
            root.aliases = ({});
        }
        try {
            const parsed = JSON.parse(archivedFile.text());
            root.archived = Array.isArray(parsed) ? parsed.filter(id => typeof id === "string") : [];
        } catch (e) {
            root.archived = [];
        }
    }

    function renameSession(id: string, title: string): void {
        if (!id)
            return;
        const next = Object.assign({}, root.aliases);
        const value = String(title || "").trim();
        if (value.length > 0)
            next[id] = value;
        else
            delete next[id];
        root.aliases = next;
        aliasesFile.setText(JSON.stringify(next) + "\n");
    }

    function toggleArchived(id: string): void {
        if (!id)
            return;
        const next = root.archived.slice();
        const index = next.indexOf(id);
        if (index >= 0)
            next.splice(index, 1);
        else
            next.push(id);
        root.archived = next;
        archivedFile.setText(JSON.stringify(next) + "\n");
    }

    function loadPins(): void {
        let ids = [];
        try {
            const parsed = JSON.parse(pinsFile.text());
            if (Array.isArray(parsed))
                ids = parsed.filter(id => typeof id === "string");
        } catch (e) {
            ids = [];
        }
        root.pinned = ids;
    }

    function togglePin(id: string): void {
        if (!id)
            return;
        const next = root.pinned.slice();
        const index = next.indexOf(id);
        if (index >= 0)
            next.splice(index, 1);
        else
            next.push(id);
        root.pinned = next;
        pinsFile.setText(JSON.stringify(next) + "\n");
    }

    FileView {
        id: pinsFile

        path: root.pinsPath
        preload: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadPins()
        onTextChanged: root.loadPins()
    }

    FileView {
        id: aliasesFile

        path: root.aliasesPath
        preload: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadSessionMeta()
        onTextChanged: root.loadSessionMeta()
    }

    FileView {
        id: archivedFile

        path: root.archivedPath
        preload: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadSessionMeta()
        onTextChanged: root.loadSessionMeta()
    }

    function setHistory(entries: var, replace: bool): void {
        if (!replace && root.messages.length > 0)
            return;
        if (!Array.isArray(entries))
            return;
        // The drawer is opened synchronously; rendering every archived message
        // with rich Markdown blocks makes that first open several seconds long.
        // Keep the recent working set and let the rest stay in the session log.
        const restored = entries.slice(-30)
            .filter(entry => entry && (entry.role === "user" || entry.role === "assistant") && typeof entry.text === "string" && entry.text.length > 0)
            .map((entry, index) => ({
                id: "history-" + index,
                role: entry.role,
                text: entry.text,
                streaming: false,
            }));
        root.messages = restored;
    }

    function appendNotice(text: string): void {
        root.messages = root.messages.concat([
            { id: "notice-" + root.nextId++, role: "notice", text: text, streaming: false },
        ]);
    }

    function handleCommand(command: string): void {
        const name = command.split(/\s+/, 1)[0].toLowerCase();
        switch (name) {
        case "/new":
        case "/clear":
            root.newChat();
            break;
        case "/resume":
            root.sessionsRequested();
            break;
        case "/stop":
            root.cancel();
            break;
        case "/quit":
            root.closeRequested();
            break;
        case "/help":
            root.appendNotice(Tr.tr("Widget commands: /new, /clear, /resume, /stop, /quit. DSH commands such as /btw and /compact require dsh-tui."));
            break;
        default:
            root.error = Tr.tr("Unknown widget command. Use /help, or run DSH commands in dsh-tui.");
            break;
        }
    }

    function send(text, attachments) {
        if (!attachments)
            attachments = [];
        text = text.trim();
        if (text.startsWith("/")) {
            root.handleCommand(text);
            return;
        }
        if ((!text && attachments.length === 0) || root.streaming || !root.ready)
            return;
        if (root.sessionOwned) {
            root.error = Tr.tr("This session is open in dsh-tui. Close it there or start a new chat.");
            return;
        }
        if (!root.configured) {
            root.error = Tr.tr("DSH is not ready");
            return;
        }

        const id = root.nextId++;
        const names = attachments.map(path => String(path).split("/").pop());
        const shown = text + (names.length > 0 ? (text.length > 0 ? "\n\n" : "") + Tr.tr("Attached: %1").arg(names.join(", ")) : "");
        root.messages = root.messages.concat([
            { id: id + "-user", role: "user", text: shown, streaming: false, attachments: attachments },
            { id: id, role: "assistant", text: "", streaming: true },
        ]);
        root.activeId = id;
        root.streaming = true;
        if (root.sessionId.length > 0)
            AssistantSettings.lastSessionId = root.sessionId;
        root.activity = Tr.tr("Thinking…");
        root.activityLog = [root.activity];
        root.lastStop = "";
        root.error = "";
        process.write(JSON.stringify({
            cmd: "chat",
            id: id,
            sessionId: root.sessionId,
            text: text,
            attachments: attachments,
        }) + "\n");
    }

    function cancel(): void {
        if (!root.streaming)
            return;
        process.write(JSON.stringify({ cmd: "cancel", id: root.activeId }) + "\n");
        const index = root.messages.findIndex(m => m.id === root.activeId);
        if (index >= 0) {
            const next = root.messages.slice();
            next[index] = Object.assign({}, next[index], { streaming: false, cancelled: true });
            root.messages = next;
        }
        root.lastStop = "cancelled";
        root.streaming = false;
        root.activeId = -1;
        root.activity = "";
    }

    function cancelOrClose(): void {
        if (root.streaming)
            root.cancel();
    }

    function newChat(): void {
        Quickshell.execDetached(["padilha-voice", "stop"]);
        if (root.streaming)
            root.cancel();
        if (root.started)
            process.write(JSON.stringify({ cmd: "new_chat" }) + "\n");
        root.sessionId = "";
        root.sessionTitle = "";
        root.sessionOwned = false;
        root.messages = [];
        AssistantSettings.lastSessionId = "";
        root.contextTokens = 0;
        root.contextWindow = 0;
        root.error = "";
        root.activityLog = [];
        root.activity = "";
        root.lastStop = "";
        root.viewingAgent = false;
    }

    function selectSession(id: string): void {
        if (!id)
            return;
        AssistantSettings.lastSessionId = id;
        if (root.streaming || id === root.sessionId)
            return;
        if (id === root.defaultSessionId)
            root.viewingAgent = false;
        root.sessionId = id;
        root.sessionTitle = "";
        root.sessionOwned = false;
        root.messages = [];
        root.contextTokens = 0;
        root.contextWindow = 0;
        root.error = "";
        if (root.started)
            process.write(JSON.stringify({ cmd: "load", sessionId: id }) + "\n");
    }

    function selectModel(id: string): void {
        if (!root.streaming)
            root.selectedModel = id;
    }

    function refreshSessions(): void {
        if (root.started)
            process.write(JSON.stringify({ cmd: "list" }) + "\n");
    }

    function refreshAgents(): void {
        if (root.started) {
            const parent = root.defaultSessionId || root.sessionId;
            if (parent.length > 0)
                process.write(JSON.stringify({ cmd: "subagents", parent }) + "\n");
        }
    }

    function handleSubagents(agents: var): void {
        root.agentSessions = agents || [];
        if (root.viewingAgent && !root.agentSessions.some(agent => agent.id === root.sessionId))
            root.viewHome();
    }

    function viewAgent(id: string): void {
        if (!id || root.streaming)
            return;
        root.viewingAgent = true;
        root.selectSession(id);
    }

    function viewHome(): void {
        if (!root.defaultSessionId || root.streaming)
            return;
        root.viewingAgent = false;
        root.selectSession(root.defaultSessionId);
    }

    function reloadCurrent(): void {
        if (root.started && root.sessionId.length > 0)
            process.write(JSON.stringify({ cmd: "load", sessionId: root.sessionId }) + "\n");
    }

    function attachFile(): void {
        // Attachments are intentionally not part of v1.
    }

    function start(): void {
        if (root.started)
            return;
        root.stopping = false;
        root.started = true;
    }

    function stop(): void {
        if (!root.started || root.streaming)
            return;
        root.stopping = true;
        root.started = false;
        root.ready = false;
    }

    Connections {
        function onSpeakRepliesChanged(): void {
            if (!AssistantSettings.speakReplies)
                Quickshell.execDetached(["padilha-voice", "stop"]);
        }

        target: AssistantSettings
    }

    Process {
        id: process

        command: ["padilha-dsh", "--stdio"]
        running: root.started
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.handle(line)
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim().length > 0)
                    console.warn("padilha-dsh:", line);
            }
        }

        onExited: {
            root.ready = false;
            root.streaming = false;
            root.started = false;
            if (root.stopping) {
                root.stopping = false;
                return;
            }
            root.error = Tr.tr("DSH backend exited.");
        }
    }
}
