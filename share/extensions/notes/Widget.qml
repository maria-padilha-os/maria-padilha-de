pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// Plain-text notes, one file per note. Persisted under
// ~/.local/share/padilha/notes (or $XDG_DATA_HOME/padilha/notes); nothing here
// talks to the network or writes anywhere else.
Item {
    id: root

    property var api
    property bool active: true
    property bool compact: false

    property var notes: []
    property string selectedFile: ""
    property bool dirty: false
    property string status: ""
    property string pendingDelete: ""
    property var writeQueue: []
    property string pendingSelect: ""
    property string loadTarget: ""

    readonly property var palette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color foreground: root.palette ? root.palette.m3onSurface : "transparent"
    readonly property color muted: root.palette ? root.palette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.palette ? root.palette.m3primary : "transparent"
    readonly property color onAccent: root.palette ? root.palette.m3onPrimary : "transparent"
    readonly property color errorColour: root.palette ? root.palette.m3error : "transparent"
    readonly property color fieldColour: root.palette ? root.palette.m3surfaceContainerHigh : "transparent"
    readonly property color outline: root.palette ? root.palette.m3outlineVariant : "transparent"

    readonly property string dataHome: {
        const home = Quickshell.env("HOME") || "";
        return Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`;
    }
    readonly property string stateDir: `${root.dataHome}/padilha/notes`
    readonly property string selectedPath: root.selectedFile.length > 0 ? `${root.stateDir}/${root.selectedFile}` : ""

    function notePath(file: string): string {
        return file.length > 0 ? `${root.stateDir}/${file}` : "";
    }

    function refresh(): void {
        if (!listProc.running)
            listProc.running = true;
    }

    function loadSelected(): void {
        if (root.selectedFile.length === 0) {
            root.loadTarget = "";
            editor.text = "";
            root.dirty = false;
            return;
        }

        root.loadTarget = root.selectedFile;
        readProc.command = ["sh", "-c", `cat -- "$1" 2>/dev/null || true`, "sh", root.selectedPath];
        readProc.running = true;
    }

    function selectNote(file: string): void {
        if (file === root.selectedFile)
            return;
        root.saveCurrent();
        root.pendingDelete = "";
        root.selectedFile = file;
    }

    function saveCurrent(): void {
        autosave.stop();
        if (root.selectedFile.length === 0 || !root.dirty)
            return;
        root.dirty = false;
        root.enqueueWrite(root.selectedFile, editor.text, false);
    }

    function enqueueWrite(file: string, content: string, selectAfter: bool): void {
        root.writeQueue = root.writeQueue.concat([{
                    file: file,
                    content: content,
                    selectAfter: selectAfter
                }]);
        root.pumpWrites();
    }

    function pumpWrites(): void {
        if (writeProc.running || root.writeQueue.length === 0)
            return;

        const job = root.writeQueue[0];
        root.pendingSelect = job.selectAfter ? job.file : "";
        writeProc.command = [
            "sh", "-c",
            `mkdir -p -- "$1" && printf '%s' "$3" > "$2.tmp" && mv -f -- "$2.tmp" "$2"`,
            "sh", root.stateDir, root.notePath(job.file), job.content
        ];
        writeProc.running = true;
    }

    function createNote(): void {
        root.saveCurrent();
        const name = `note-${Date.now()}-${Math.floor(Math.random() * 100000)}.txt`;
        root.selectedFile = name;
        root.dirty = false;
        root.enqueueWrite(name, "", true);
        root.status = Tr.tr("New note");
    }

    function requestDelete(): void {
        if (root.selectedFile.length === 0)
            return;
        if (writeProc.running || root.writeQueue.length > 0) {
            root.status = Tr.tr("Wait for the note to save before deleting it.");
            return;
        }
        if (root.pendingDelete !== root.selectedFile) {
            root.pendingDelete = root.selectedFile;
            root.status = Tr.tr("Press delete again to remove this note.");
            return;
        }
        removeProc.command = ["sh", "-c", `rm -f -- "$1"`, "sh", root.selectedPath];
        removeProc.running = true;
    }

    function formatTitle(title: string): string {
        return title.length > 0 ? title : Tr.tr("Untitled note");
    }

    Component.onCompleted: root.refresh()

    onActiveChanged: {
        if (!root.active)
            root.saveCurrent();
    }

    onSelectedFileChanged: root.loadSelected()

    onNotesChanged: {
        if (root.notes.length === 0) {
            root.pendingDelete = "";
            return;
        }
        if (!root.notes.some(note => note.file === root.selectedFile))
            root.selectedFile = root.notes[0].file;
    }

    Timer {
        id: autosave

        interval: 700
        onTriggered: root.saveCurrent()
    }

    Process {
        id: listProc

        command: [
            "sh", "-c",
            `[ -d "$1" ] || exit 0; find "$1" -mindepth 1 -maxdepth 1 -type f -name '*.txt' -printf '%T@\\t%f\\n' 2>/dev/null | sort -rn | while IFS="$(printf '\\t')" read -r stamp name; do [ -n "$name" ] || continue; title=$(head -n 1 -- "$1/$name" 2>/dev/null | tr '\\t\\r\\n' '   ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | cut -c1-80); printf '%s\\t%s\\n' "$name" "$title"; done`,
            "sh", root.stateDir
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = [];
                for (const line of text.split("\n")) {
                    if (line.length === 0)
                        continue;
                    const tab = line.indexOf("\t");
                    if (tab < 1)
                        continue;
                    parsed.push({
                        file: line.slice(0, tab),
                        title: line.slice(tab + 1)
                    });
                }
                root.notes = parsed;
            }
        }
    }

    Process {
        id: readProc

        stdout: StdioCollector {
            id: readOut
        }

        onExited: (exitCode) => {
            if (exitCode !== 0 || root.loadTarget !== root.selectedFile)
                return;
            if (root.dirty)
                return;
            const value = readOut.text;
            if (editor.text !== value) {
                editor.text = value;
                root.dirty = false;
            }
        }
    }

    Process {
        id: writeProc

        onExited: (exitCode) => {
            const job = root.writeQueue.length > 0 ? root.writeQueue[0] : null;
            if (!job) {
                root.pendingSelect = "";
                return;
            }

            if (exitCode === 0) {
                root.writeQueue = root.writeQueue.slice(1);
                if (root.pendingSelect.length > 0)
                    root.selectedFile = root.pendingSelect;
                root.pendingSelect = "";
                root.status = Tr.tr("Saved");
                root.refresh();
            } else {
                root.writeQueue = [];
                root.pendingSelect = "";
                root.dirty = true;
                root.status = Tr.tr("Could not save the note.");
            }
            root.pumpWrites();
        }
    }

    Process {
        id: removeProc

        onExited: (exitCode) => {
            if (exitCode === 0) {
                const removed = root.selectedFile;
                root.notes = root.notes.filter(note => note.file !== removed);
                root.selectedFile = "";
                root.dirty = false;
                root.pendingDelete = "";
                root.status = Tr.tr("Note deleted");
                root.refresh();
            } else {
                root.status = Tr.tr("Could not delete the note.");
            }
        }
    }

    component ActionButton: Rectangle {
        id: button

        property string label
        property bool primary: false
        signal clicked()

        implicitWidth: Math.max(30, labelText.implicitWidth + Tokens.padding.large)
        implicitHeight: 30
        radius: Tokens.rounding.small
        color: button.primary ? (buttonMouse.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent) : (buttonMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent")
        border.width: button.primary ? 0 : 1
        border.color: root.outline
        opacity: button.enabled ? 1 : 0.45

        Text {
            id: labelText

            anchors.centerIn: parent
            text: button.label
            color: button.primary ? root.onAccent : root.foreground
            font: Tokens.font.label.medium
            elide: Text.ElideRight
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? Tokens.padding.medium : Tokens.padding.large
        spacing: Tokens.spacing.small

        Rectangle {
            Layout.preferredWidth: root.compact ? 190 : 220
            Layout.fillHeight: true
            radius: Tokens.rounding.medium
            color: root.fieldColour
            border.width: 1
            border.color: root.outline

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.extraSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    Text {
                        Layout.fillWidth: true
                        text: Tr.tr("Notes")
                        color: root.foreground
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    ActionButton {
                        label: "+"
                        primary: true
                        onClicked: root.createNote()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.notes.length === 0
                    text: Tr.tr("No notes yet")
                    color: root.muted
                    font: Tokens.font.label.small
                }

                ListView {
                    id: noteList

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.notes
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: 2

                    delegate: Rectangle {
                        id: noteRow

                        required property var modelData

                        width: ListView.view.width
                        height: 42
                        radius: Tokens.rounding.small
                        color: root.selectedFile === noteRow.modelData.file ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (noteMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06) : "transparent")

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.small
                            anchors.rightMargin: Tokens.padding.small
                            spacing: 1

                            Text {
                                width: parent.width
                                text: root.formatTitle(noteRow.modelData.title)
                                color: root.foreground
                                font: Tokens.font.label.medium
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: noteRow.modelData.file
                                color: root.muted
                                font: Tokens.font.label.small
                                elide: Text.ElideMiddle
                            }
                        }

                        MouseArea {
                            id: noteMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectNote(noteRow.modelData.file)
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                Text {
                    Layout.fillWidth: true
                    text: root.selectedFile.length > 0 ? root.formatTitle(root.notes.find(note => note.file === root.selectedFile)?.title ?? "") : Tr.tr("New note")
                    color: root.foreground
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                ActionButton {
                    label: root.dirty ? Tr.tr("Save") : Tr.tr("Saved")
                    primary: root.dirty
                    enabled: root.selectedFile.length > 0 && root.dirty
                    onClicked: root.saveCurrent()
                }

                ActionButton {
                    label: root.pendingDelete === root.selectedFile && root.selectedFile.length > 0 ? Tr.tr("Delete?") : Tr.tr("Delete")
                    enabled: root.selectedFile.length > 0
                    onClicked: root.requestDelete()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Tokens.rounding.medium
                color: root.fieldColour
                border.width: 1
                border.color: editor.activeFocus ? root.accent : root.outline
                clip: true

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    clip: true

                    TextArea {
                        id: editor

                        wrapMode: TextArea.Wrap
                        color: root.foreground
                        selectionColor: root.accent
                        selectedTextColor: root.onAccent
                        placeholderText: Tr.tr("Write a plain-text note…")
                        placeholderTextColor: root.muted
                        font: Tokens.font.body.medium
                        background: null
                        padding: 0

                        onTextChanged: {
                            if (!root.dirty)
                                root.dirty = true;
                            if (root.active)
                                autosave.restart();
                        }

                        Keys.onPressed: (event) => {
                            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                                root.saveCurrent();
                                event.accepted = true;
                            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N) {
                                root.createNote();
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.status.length > 0 ? root.status : Tr.tr("Ctrl+S saves, Ctrl+N creates a note")
                color: root.pendingDelete.length > 0 || root.status.indexOf(Tr.tr("Could not")) === 0 ? root.errorColour : root.muted
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }
    }
}
