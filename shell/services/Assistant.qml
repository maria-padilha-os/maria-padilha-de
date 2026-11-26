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
    property string selectedModel: ""
    property list<var> models: []
    property list<var> roots: []
    property list<var> sessions: []
    property string sessionId: ""
    property string sessionTitle: ""
    property bool sessionOwned: false
    property list<var> messages: []
    property int nextId: 1
    property int activeId: -1
    property bool started: false
    property bool stopping: false

    signal sessionsRequested()
    signal closeRequested()

    readonly property bool configured: models.length > 0
    readonly property string rootsLabel: roots.length === 0 ? Tr.tr("No folders granted") : Tr.trN("%n folder granted", "%n folders granted", roots.length)
    readonly property string sessionLabel: sessionTitle.length > 0 ? sessionTitle : Tr.tr("No DSH session")
    readonly property string modelLabel: {
        const model = models.find(m => m.id === selectedModel);
        return model ? model.name : Tr.tr("DeepSeek Harness");
    }
    readonly property bool speakReplies: AssistantSettings.speakReplies

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
            root.activity = "";
            root.models = event.models || [];
            root.roots = event.roots || [];
            root.selectedModel = root.selectedModel || (root.models[0]?.id ?? "");
            root.sessions = event.sessions || [];
            root.sessionId = event.sessionId || "";
            root.sessionTitle = event.sessionTitle || "";
            root.sessionOwned = !!event.sessionOwned;
            root.setHistory(event.history, false);
            root.error = "";
            break;
        case "history":
            root.activity = "";
            root.sessionId = event.sessionId || root.sessionId;
            root.sessionTitle = event.sessionTitle || "";
            root.sessionOwned = !!event.sessionOwned;
            root.messages = [];
            root.setHistory(event.history, true);
            root.streaming = false;
            root.activeId = -1;
            break;
        case "new":
            root.activity = "";
            root.sessionId = event.sessionId || "";
            root.sessionTitle = "";
            root.sessionOwned = false;
            root.messages = [];
            root.error = "";
            break;
        case "session":
            root.sessionId = event.sessionId || root.sessionId;
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
        case "activity":
            if (event.id === root.activeId)
                root.activity = event.text || "";
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
            root.streaming = false;
            root.activeId = -1;
            root.activity = "";
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
            root.streaming = false;
            root.activeId = -1;
            root.activity = "";
            break;
        }
        }
    }

    function setHistory(entries: var, replace: bool): void {
        if (!replace && root.messages.length > 0)
            return;
        if (!Array.isArray(entries))
            return;
        const restored = entries
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

    function send(text: string): void {
        text = text.trim();
        if (text.startsWith("/")) {
            root.handleCommand(text);
            return;
        }
        if (!text || root.streaming || !root.ready)
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
        root.messages = root.messages.concat([
            { id: id + "-user", role: "user", text: text, streaming: false },
            { id: id, role: "assistant", text: "", streaming: true },
        ]);
        root.activeId = id;
        root.streaming = true;
        root.activity = Tr.tr("Thinking…");
        root.error = "";
        process.write(JSON.stringify({
            cmd: "chat",
            id: id,
            sessionId: root.sessionId,
            text: text,
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
        root.error = "";
    }

    function selectSession(id: string): void {
        if (!id || root.streaming || id === root.sessionId)
            return;
        root.sessionId = id;
        root.sessionTitle = "";
        root.sessionOwned = false;
        root.messages = [];
        root.error = "";
        if (root.started)
            process.write(JSON.stringify({ cmd: "load", sessionId: id }) + "\n");
    }

    function selectModel(id: string): void {
        if (!root.streaming)
            root.selectedModel = id;
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
