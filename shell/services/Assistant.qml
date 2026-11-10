pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool ready: false
    property bool streaming: false
    property string error: ""
    property string selectedModel: ""
    property list<var> models: []
    property list<var> roots: []
    property list<var> messages: []
    property int nextId: 1
    property int activeId: -1

    readonly property bool configured: models.length > 0
    readonly property string rootsLabel: roots.length === 0 ? "No folders granted" : roots.map(r => r.display || r.path).join(" · ")
    readonly property string modelLabel: {
        const model = models.find(m => m.id === selectedModel);
        return model ? model.name : "No model configured";
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
            root.roots = event.root_entries || [];
            root.selectedModel = root.selectedModel || (root.models[0]?.id ?? "");
            root.error = event.chat ? "" : "No chat provider configured. Add models and providers to ~/.config/padilha/ai.lua.";
            break;
        case "done": {
            if (event.id !== root.activeId)
                return;
            const index = root.messages.findIndex(m => m.id === event.id);
            if (index >= 0) {
                const next = root.messages.slice();
                next[index] = Object.assign({}, next[index], {
                    text: event.text || "",
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
            if (event.id !== root.activeId && event.id !== undefined)
                return;
            root.error = event.message || "Assistant request failed";
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

    function send(text: string): void {
        text = text.trim();
        if (!text || root.streaming || !root.ready)
            return;
        if (!root.configured) {
            root.error = "No chat provider configured. Add models and providers to ~/.config/padilha/ai.lua.";
            return;
        }

        const id = root.nextId++;
        const history = root.messages
            .filter(m => !m.streaming && !m.error && m.role !== "notice")
            .map(m => ({ role: m.role, content: m.text }));
        history.push({ role: "user", content: text });

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
            model: root.selectedModel,
            messages: history,
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
        root.cancel();
        root.messages = [];
        root.error = "";
    }

    function selectModel(id: string): void {
        if (!root.streaming)
            root.selectedModel = id;
    }

    function attachFile(): void {
        // Attachments are intentionally not part of v1.
    }

    Process {
        id: process

        command: ["padilha-ai", "--stdio"]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.handle(line)
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim().length > 0)
                    console.warn("padilha-ai:", line);
            }
        }

        onExited: {
            root.ready = false;
            root.streaming = false;
            root.error = "Assistant backend exited.";
        }
    }
}
