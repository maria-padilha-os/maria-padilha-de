pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n

Singleton {
    id: root

    property bool ready: false
    property bool streaming: false
    property string error: ""
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

    readonly property bool configured: models.length > 0
    readonly property string rootsLabel: roots.length === 0 ? Tr.tr("No folders granted") : Tr.trN("%n folder granted", "%n folders granted", roots.length)
    readonly property string sessionLabel: sessionTitle.length > 0 ? sessionTitle : Tr.tr("No DSH session")
    readonly property string modelLabel: {
        const model = models.find(m => m.id === selectedModel);
        return model ? model.name : Tr.tr("DeepSeek Harness");
    }

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
            root.sessionId = event.sessionId || root.sessionId;
            root.sessionTitle = event.sessionTitle || "";
            root.sessionOwned = !!event.sessionOwned;
            root.messages = [];
            root.setHistory(event.history, true);
            root.streaming = false;
            root.activeId = -1;
            break;
        case "new":
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

    function send(text: string): void {
        text = text.trim();
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
    }

    function cancelOrClose(): void {
        if (root.streaming)
            root.cancel();
    }

    function newChat(): void {
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
