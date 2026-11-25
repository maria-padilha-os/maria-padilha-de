pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// Local address book. Contacts live in
// ~/.local/share/padilha/contacts/contacts.json (or the same path under
// $XDG_DATA_HOME); nothing here talks to the network.
Item {
    id: root

    property var api
    property bool active: true
    property bool compact: false

    property var contacts: []
    property string selectedId: ""
    property string query: ""
    property string editName: ""
    property string editEmail: ""
    property string editPhone: ""
    property string editNotes: ""
    property bool dirty: false
    property bool loaded: false
    property bool deleteArmed: false
    property string status: ""
    property string statusKind: ""
    property string pendingPayload: ""

    readonly property var themePalette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color foreground: root.themePalette ? root.themePalette.m3onSurface : "transparent"
    readonly property color muted: root.themePalette ? root.themePalette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.themePalette ? root.themePalette.m3primary : "transparent"
    readonly property color onAccent: root.themePalette ? root.themePalette.m3onPrimary : "transparent"
    readonly property color errorColour: root.themePalette ? root.themePalette.m3error : "transparent"
    readonly property color fieldColour: root.themePalette ? root.themePalette.m3surfaceContainerHigh : "transparent"
    readonly property color surface: root.themePalette ? root.themePalette.m3surfaceContainerLow : "transparent"
    readonly property color outline: root.themePalette ? root.themePalette.m3outlineVariant : "transparent"

    readonly property string dataHome: {
        const home = Quickshell.env("HOME") || "";
        return Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`;
    }
    readonly property string stateDir: `${root.dataHome}/padilha/contacts`
    readonly property string storePath: `${root.stateDir}/contacts.json`

    readonly property var filtered: {
        const needle = root.query.trim().toLowerCase();
        const items = root.contacts.slice().sort((a, b) => a.name.localeCompare(b.name));
        if (needle.length === 0)
            return items;
        return items.filter(contact => [contact.name, contact.email, contact.phone, contact.notes].some(value => String(value).toLowerCase().indexOf(needle) !== -1));
    }

    function normaliseContact(raw: var): var {
        if (!raw || typeof raw !== "object")
            return null;
        const name = typeof raw.name === "string" ? raw.name.trim() : "";
        if (name.length === 0)
            return null;
        return {
            id: typeof raw.id === "string" && raw.id.length > 0 ? raw.id : `contact-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
            name: name,
            email: typeof raw.email === "string" ? raw.email.trim() : "",
            phone: typeof raw.phone === "string" ? raw.phone.trim() : "",
            notes: typeof raw.notes === "string" ? raw.notes : ""
        };
    }

    function load(): void {
        readProc.command = ["sh", "-c", `cat -- "$1" 2>/dev/null || true`, "sh", root.storePath];
        readProc.running = true;
    }

    function handleLoad(text: string): void {
        root.loaded = true;
        const source = text.trim();
        if (source.length === 0) {
            root.contacts = [];
            return;
        }
        try {
            const data = JSON.parse(source);
            const raw = Array.isArray(data) ? data : data && Array.isArray(data.contacts) ? data.contacts : [];
            root.contacts = raw.map(contact => root.normaliseContact(contact)).filter(contact => contact !== null);
            if (root.contacts.length > 0)
                root.selectContact(root.contacts[0].id);
        } catch (error) {
            root.statusKind = "error";
            root.status = Tr.tr("Could not read the contacts file.");
        }
    }

    function selectContact(id: string): void {
        if (root.dirty)
            root.save();
        const contact = root.contacts.find(item => item.id === id);
        if (!contact)
            return;
        root.selectedId = id;
        root.editName = contact.name;
        root.editEmail = contact.email;
        root.editPhone = contact.phone;
        root.editNotes = contact.notes;
        root.dirty = false;
        root.deleteArmed = false;
        root.status = "";
        root.statusKind = "";
    }

    function addContact(): void {
        if (root.dirty)
            root.save();
        const contact = {
            id: `contact-${Date.now()}`,
            name: Tr.tr("New contact"),
            email: "",
            phone: "",
            notes: ""
        };
        root.contacts = root.contacts.concat([contact]);
        root.selectedId = contact.id;
        root.editName = contact.name;
        root.editEmail = "";
        root.editPhone = "";
        root.editNotes = "";
        root.dirty = false;
        root.deleteArmed = false;
        root.status = "";
        root.statusKind = "";
        root.persist();
        Qt.callLater(() => {
            nameField.focusInput();
        });
    }

    function save(): bool {
        if (!root.loaded || root.selectedId.length === 0)
            return false;
        const name = root.editName.trim();
        if (name.length === 0) {
            root.statusKind = "error";
            root.status = Tr.tr("A name is required.");
            return false;
        }
        root.contacts = root.contacts.map(contact => contact.id === root.selectedId ? {
            id: contact.id,
            name: name,
            email: root.editEmail.trim(),
            phone: root.editPhone.trim(),
            notes: root.editNotes
        } : contact);
        root.dirty = false;
        root.statusKind = "ok";
        root.status = Tr.tr("Saved");
        root.persist();
        return true;
    }

    function markDirty(): void {
        root.dirty = true;
        root.status = "";
        root.statusKind = "";
        autosave.restart();
    }

    function deleteSelected(): void {
        if (root.selectedId.length === 0)
            return;
        if (!root.deleteArmed) {
            root.deleteArmed = true;
            root.statusKind = "delete";
            root.status = Tr.tr("Press Delete again to remove this contact");
            deleteTimer.restart();
            return;
        }
        root.contacts = root.contacts.filter(contact => contact.id !== root.selectedId);
        root.selectedId = "";
        root.editName = "";
        root.editEmail = "";
        root.editPhone = "";
        root.editNotes = "";
        root.dirty = false;
        root.deleteArmed = false;
        root.status = "";
        root.statusKind = "";
        root.persist();
        if (root.contacts.length > 0)
            root.selectContact(root.contacts[0].id);
    }

    function persist(): void {
        root.pendingPayload = JSON.stringify({
            version: 1,
            contacts: root.contacts
        });
        root.flushWrite();
    }

    function flushWrite(): void {
        if (writeProc.running || root.pendingPayload.length === 0)
            return;
        const payload = root.pendingPayload;
        root.pendingPayload = "";
        writeProc.command = [
            "sh", "-c",
            `mkdir -p -- "$1" && printf '%s' "$3" > "$2.tmp" && chmod 600 -- "$2.tmp" && mv -f -- "$2.tmp" "$2"`,
            "sh", root.stateDir, root.storePath, payload
        ];
        writeProc.running = true;
    }

    Component.onCompleted: root.load()

    onActiveChanged: {
        if (!root.active && root.dirty)
            root.save();
    }

    Timer {
        id: autosave

        interval: 700
        onTriggered: root.save()
    }

    Timer {
        id: deleteTimer

        interval: 4000
        onTriggered: {
            root.deleteArmed = false;
            if (root.statusKind === "delete") {
                root.status = "";
                root.statusKind = "";
            }
        }
    }

    Process {
        id: readProc

        stdout: StdioCollector {
            id: readOutput
        }

        onExited: root.handleLoad(readOutput.text)
    }

    Process {
        id: writeProc

        stderr: StdioCollector {
            id: writeError
        }

        onExited: code => {
            if (root.pendingPayload.length > 0) {
                root.flushWrite();
                return;
            }
            if (code !== 0) {
                root.statusKind = "error";
                root.status = writeError.text.trim() || Tr.tr("Could not save contacts.");
            } else if (root.statusKind !== "error") {
                root.statusKind = "ok";
                root.status = Tr.tr("Saved");
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Text {
                text: Tr.tr("Contacts")
                color: root.foreground
                font: Tokens.font.body.large
            }

            Text {
                text: Tr.trN("%n contact", "%n contacts", root.contacts.length)
                color: root.muted
                font: Tokens.font.label.medium
            }

            Item {
                Layout.fillWidth: true
            }

            ActionButton {
                label: Tr.tr("Add")
                primary: true
                onActivated: root.addContact()
            }
        }

        Input {
            id: search

            Layout.fillWidth: true
            placeholderText: Tr.tr("Search contacts")
            onTextEdited: root.query = text
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            Rectangle {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                radius: Tokens.rounding.large
                color: root.surface
                border.width: 1
                border.color: root.outline

                ListView {
                    id: listView

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filtered

                    delegate: Rectangle {
                        id: contactRow

                        required property var modelData

                        width: ListView.view.width
                        implicitHeight: 54
                        radius: Tokens.rounding.small
                        color: contactRow.modelData.id === root.selectedId ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : contactMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06) : "transparent"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: contactRow.modelData.name
                                color: root.foreground
                                font: Tokens.font.label.large
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: contactRow.modelData.email.length > 0 ? contactRow.modelData.email : contactRow.modelData.phone.length > 0 ? contactRow.modelData.phone : Tr.tr("No details")
                                color: root.muted
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: contactMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectContact(contactRow.modelData.id)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - Tokens.padding.large * 2
                    visible: root.filtered.length === 0
                    text: root.contacts.length === 0 ? Tr.tr("No contacts yet.") : Tr.tr("No contacts match.")
                    color: root.muted
                    font: Tokens.font.label.medium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.small
                visible: root.selectedId.length > 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Field {
                        id: nameField

                        Layout.fillWidth: true
                        label: Tr.tr("Name")
                        placeholder: Tr.tr("Full name")
                        text: root.editName
                        onEdited: value => {
                            root.editName = value;
                            root.markDirty();
                        }
                    }

                    ActionButton {
                        Layout.alignment: Qt.AlignBottom
                        label: Tr.tr("Save")
                        primary: true
                        onActivated: root.save()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Field {
                        Layout.fillWidth: true
                        label: Tr.tr("Email")
                        placeholder: Tr.tr("name@example.com")
                        text: root.editEmail
                        onEdited: value => {
                            root.editEmail = value;
                            root.markDirty();
                        }
                    }

                    Field {
                        Layout.fillWidth: true
                        label: Tr.tr("Phone")
                        placeholder: Tr.tr("+55 ...")
                        text: root.editPhone
                        onEdited: value => {
                            root.editPhone = value;
                            root.markDirty();
                        }
                    }
                }

                Text {
                    text: Tr.tr("Notes")
                    color: root.muted
                    font: Tokens.font.label.small
                }

                ScrollView {
                    id: notesScroll

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        id: notesField

                        width: notesScroll.availableWidth
                        text: root.editNotes
                        color: root.foreground
                        placeholderText: Tr.tr("Birthdays, addresses, anything...")
                        placeholderTextColor: root.muted
                        wrapMode: Text.Wrap
                        selectByMouse: true
                        font: Tokens.font.body.medium
                        background: Rectangle {
                            color: root.fieldColour
                            radius: Tokens.rounding.small
                            border.width: 1
                            border.color: notesField.activeFocus ? root.accent : root.outline
                        }

                        onTextChanged: {
                            if (text === root.editNotes)
                                return;
                            root.editNotes = text;
                            root.markDirty();
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    ActionButton {
                        label: root.deleteArmed ? Tr.tr("Confirm delete") : Tr.tr("Delete")
                        danger: true
                        onActivated: root.deleteSelected()
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        Layout.maximumWidth: 360
                        text: root.status
                        color: root.statusKind === "error" ? root.errorColour : root.muted
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.selectedId.length === 0
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    width: parent.width - Tokens.padding.large * 2
                    text: root.contacts.length === 0 ? Tr.tr("Add a contact to get started.") : Tr.tr("Select a contact to edit it.")
                    color: root.muted
                    font: Tokens.font.label.medium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    component Input: TextField {
        id: input

        color: root.foreground
        placeholderTextColor: root.muted
        font: Tokens.font.body.medium
        selectByMouse: true
        leftPadding: Tokens.padding.medium
        rightPadding: Tokens.padding.medium
        topPadding: Tokens.padding.small
        bottomPadding: Tokens.padding.small
        implicitHeight: 36

        background: Rectangle {
            color: root.fieldColour
            radius: Tokens.rounding.small
            border.width: 1
            border.color: input.activeFocus ? root.accent : root.outline
        }
    }

    component Field: ColumnLayout {
        id: field

        property string label
        property string placeholder
        property alias text: input.text

        signal edited(string value)

        function focusInput(): void {
            input.forceActiveFocus();
            input.selectAll();
        }

        spacing: 4

        Text {
            text: field.label
            color: root.muted
            font: Tokens.font.label.small
        }

        Input {
            id: input

            Layout.fillWidth: true
            placeholderText: field.placeholder
            onTextEdited: field.edited(text)
        }
    }

    component ActionButton: Rectangle {
        id: button

        property string label
        property bool primary: false
        property bool danger: false

        signal activated()

        implicitWidth: Math.max(64, labelText.implicitWidth + Tokens.padding.large * 2)
        implicitHeight: 34
        radius: Tokens.rounding.small
        color: button.primary ? root.accent : "transparent"
        border.width: button.primary ? 0 : button.activeFocus ? 2 : 1
        border.color: button.danger ? root.errorColour : button.activeFocus ? root.accent : root.outline
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: button.label
        Accessible.focusable: true
        Accessible.focused: activeFocus
        Accessible.onPressAction: button.activated()

        Keys.onReturnPressed: button.activated()
        Keys.onEnterPressed: button.activated()
        Keys.onSpacePressed: button.activated()

        Text {
            id: labelText

            anchors.centerIn: parent
            text: button.label
            color: button.primary ? root.onAccent : button.danger ? root.errorColour : root.foreground
            font: Tokens.font.label.medium
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                button.forceActiveFocus();
                button.activated();
            }
        }
    }
}
