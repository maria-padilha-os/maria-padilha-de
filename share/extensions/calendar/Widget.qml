pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// Local month view and events. Events live in
// ~/.local/share/padilha/calendar/events.json (or the same path under
// $XDG_DATA_HOME); there is no account, credential, or network access.
Item {
    id: root

    property var api
    property bool active: true
    property bool compact: false

    property var events: []
    property string selectedKey: root.dateKey(new Date())
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property string status: ""
    property bool savePending: false

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
    readonly property string stateDir: `${root.dataHome}/padilha/calendar`
    readonly property string eventsPath: `${root.stateDir}/events.json`
    readonly property var weekdays: [Tr.tr("Mon"), Tr.tr("Tue"), Tr.tr("Wed"), Tr.tr("Thu"), Tr.tr("Fri"), Tr.tr("Sat"), Tr.tr("Sun")]
    readonly property string todayKey: root.dateKey(new Date())
    readonly property string monthLabel: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
    readonly property var selectedEvents: root.events.filter(event => event.date === root.selectedKey)
    readonly property string selectedLabel: Qt.formatDate(root.keyDate(root.selectedKey), "dddd, d MMMM")

    readonly property var cells: {
        const first = new Date(root.viewYear, root.viewMonth, 1);
        const offset = (first.getDay() + 6) % 7;
        const list = [];
        for (let i = 0; i < 42; i++) {
            const date = new Date(root.viewYear, root.viewMonth, 1 - offset + i);
            const key = root.dateKey(date);
            list.push({
                key: key,
                day: date.getDate(),
                inMonth: date.getMonth() === root.viewMonth,
                today: key === root.todayKey,
                selected: key === root.selectedKey,
                count: root.events.filter(event => event.date === key).length
            });
        }
        return list;
    }

    function pad(value: int): string {
        return value < 10 ? `0${value}` : `${value}`;
    }

    function dateKey(date: var): string {
        return `${date.getFullYear()}-${root.pad(date.getMonth() + 1)}-${root.pad(date.getDate())}`;
    }

    function keyDate(key: string): var {
        const parts = key.split("-").map(Number);
        return new Date(parts[0], parts[1] - 1, parts[2] || 1, 12, 0, 0);
    }

    function normaliseEvent(raw: var): var {
        if (!raw || typeof raw !== "object")
            return null;
        const date = typeof raw.date === "string" ? raw.date : "";
        const title = typeof raw.title === "string" ? raw.title.trim() : "";
        if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || title.length === 0)
            return null;
        const time = typeof raw.time === "string" ? raw.time.trim() : "";
        return {
            id: typeof raw.id === "string" && raw.id.length > 0 ? raw.id : `${date}-${Math.floor(Math.random() * 1000000)}`,
            date: date,
            title: title,
            time: /^([01]?\d|2[0-3]):[0-5]\d$/.test(time) ? time : ""
        };
    }

    function loadEvents(): void {
        readProc.command = ["sh", "-c", `cat -- "$1" 2>/dev/null || true`, "sh", root.eventsPath];
        readProc.running = true;
    }

    function saveEvents(): void {
        if (saveProc.running) {
            root.savePending = true;
            return;
        }

        root.savePending = false;
        const payload = JSON.stringify({
            version: 1,
            events: root.events
        });
        saveProc.command = [
            "sh", "-c",
            `mkdir -p -- "$1" && [ ! -f "$2" ] || cp -f -- "$2" "$2.bak"; printf '%s' "$3" > "$2.tmp" && mv -f -- "$2.tmp" "$2"`,
            "sh", root.stateDir, root.eventsPath, payload
        ];
        saveProc.running = true;
    }

    function addEventValues(date: string, title: string, time: string): bool {
        const cleanTitle = title.trim();
        if (cleanTitle.length === 0) {
            root.status = Tr.tr("Give the event a title.");
            return false;
        }

        let cleanTime = time.trim();
        if (cleanTime.length > 0) {
            if (!/^([01]?\d|2[0-3]):[0-5]\d$/.test(cleanTime)) {
                root.status = Tr.tr("Use a time like 09:30, or leave it empty.");
                return false;
            }
            const parts = cleanTime.split(":");
            cleanTime = `${root.pad(Number(parts[0]))}:${parts[1]}`;
        }

        const event = {
            id: `${Date.now()}-${Math.floor(Math.random() * 100000)}`,
            date: date,
            title: cleanTitle,
            time: cleanTime
        };
        root.events = root.events.concat([event]);
        root.status = Tr.tr("Event added");
        root.saveEvents();
        return true;
    }

    function addEvent(): void {
        if (!root.addEventValues(root.selectedKey, titleField.text, timeField.text)) {
            if (titleField.text.trim().length === 0)
                titleField.forceActiveFocus();
            else
                timeField.forceActiveFocus();
            return;
        }
        titleField.text = "";
        timeField.text = "";
    }

    function deleteEvent(id: string): void {
        root.events = root.events.filter(event => event.id !== id);
        root.status = Tr.tr("Event deleted");
        root.saveEvents();
    }

    function shiftMonth(delta: int): void {
        const date = new Date(root.viewYear, root.viewMonth + delta, 1);
        root.viewYear = date.getFullYear();
        root.viewMonth = date.getMonth();
        root.selectedKey = root.dateKey(date);
    }

    function goToday(): void {
        const now = new Date();
        root.viewYear = now.getFullYear();
        root.viewMonth = now.getMonth();
        root.selectedKey = root.dateKey(now);
        root.status = "";
    }

    function chooseDay(cell: var): void {
        root.selectedKey = cell.key;
        if (!cell.inMonth) {
            const date = root.keyDate(cell.key);
            root.viewYear = date.getFullYear();
            root.viewMonth = date.getMonth();
        }
        root.status = "";
    }

    Component.onCompleted: root.loadEvents()

    Process {
        id: readProc

        stdout: StdioCollector {
            id: readOut
        }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.status = Tr.tr("Could not read the calendar file.");
                return;
            }

            const raw = readOut.text.trim();
            if (raw.length === 0) {
                root.events = [];
                return;
            }

            try {
                const data = JSON.parse(raw);
                const list = Array.isArray(data) ? data : data?.events;
                if (!Array.isArray(list))
                    throw new Error("events is not a list");
                root.events = list.map(root.normaliseEvent).filter(event => event !== null);
                root.status = data?.version === 1 || Array.isArray(data) ? "" : Tr.tr("Calendar file version is not recognised.");
            } catch (error) {
                root.events = [];
                root.status = Tr.tr("The calendar file could not be read; the next save keeps a backup.");
            }
        }
    }

    Process {
        id: saveProc

        onExited: (exitCode) => {
            root.status = exitCode === 0 ? Tr.tr("Events saved") : Tr.tr("Could not save the calendar file.");
            if (root.savePending) {
                root.savePending = false;
                root.saveEvents();
            }
        }
    }

    component PillButton: Rectangle {
        id: button

        property string label
        property bool primary: false
        signal clicked()

        implicitWidth: Math.max(28, buttonLabel.implicitWidth + Tokens.padding.large)
        implicitHeight: 28
        radius: Tokens.rounding.small
        color: button.primary ? (buttonMouse.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent) : (buttonMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent")
        border.width: button.primary ? 0 : 1
        border.color: root.outline
        opacity: button.enabled ? 1 : 0.45

        Text {
            id: buttonLabel

            anchors.centerIn: parent
            text: button.label
            color: button.primary ? root.onAccent : root.foreground
            font: Tokens.font.label.medium
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? Tokens.padding.medium : Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            PillButton {
                label: "‹"
                onClicked: root.shiftMonth(-1)
            }

            Text {
                Layout.fillWidth: true
                text: root.monthLabel
                color: root.foreground
                font: Tokens.font.body.large
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            PillButton {
                label: "›"
                onClicked: root.shiftMonth(1)
            }

            PillButton {
                label: Tr.tr("Today")
                onClicked: root.goToday()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.medium

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.extraSmall

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 3
                    rowSpacing: 3

                    Repeater {
                        model: root.weekdays

                        delegate: Text {
                            required property string modelData

                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: root.muted
                            font: Tokens.font.label.small
                        }
                    }

                    Repeater {
                        model: root.cells

                        delegate: Rectangle {
                            id: dayCell

                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: Tokens.rounding.small
                            color: dayCell.modelData.selected ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : (dayMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07) : "transparent")
                            border.width: dayCell.modelData.today ? 1 : 0
                            border.color: root.accent
                            opacity: dayCell.modelData.inMonth ? 1 : 0.45

                            Text {
                                anchors.centerIn: parent
                                text: dayCell.modelData.day
                                color: dayCell.modelData.selected ? root.accent : root.foreground
                                font: Tokens.font.label.medium
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 3
                                visible: dayCell.modelData.count > 0
                                text: dayCell.modelData.count
                                color: root.accent
                                font: Tokens.font.label.small
                            }

                            MouseArea {
                                id: dayMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.chooseDay(dayCell.modelData)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.status.length > 0 ? root.status : Tr.tr("Local events, saved on this machine only")
                    color: root.status.indexOf(Tr.tr("Could not")) === 0 ? root.errorColour : root.muted
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.preferredWidth: 240
                Layout.fillHeight: true
                radius: Tokens.rounding.medium
                color: root.fieldColour
                border.width: 1
                border.color: root.outline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: Tokens.spacing.extraSmall

                    Text {
                        Layout.fillWidth: true
                        text: root.selectedLabel
                        color: root.foreground
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.selectedEvents.length === 0
                        text: Tr.tr("No events for this day")
                        color: root.muted
                        font: Tokens.font.label.small
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.selectedEvents
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: eventRow

                            required property var modelData

                            width: ListView.view.width
                            height: 38
                            radius: Tokens.rounding.small
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.small
                                anchors.rightMargin: 2
                                spacing: Tokens.spacing.extraSmall

                                Text {
                                    Layout.fillWidth: true
                                    text: (eventRow.modelData.time.length > 0 ? eventRow.modelData.time + "  " : "") + eventRow.modelData.title
                                    color: root.foreground
                                    font: Tokens.font.label.medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "×"
                                    color: root.muted
                                    font: Tokens.font.body.medium
                                    padding: Tokens.padding.small

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.deleteEvent(eventRow.modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        TextField {
                            id: titleField

                            Layout.fillWidth: true
                            placeholderText: Tr.tr("Event title")
                            color: root.foreground
                            placeholderTextColor: root.muted
                            font: Tokens.font.label.medium
                            background: Rectangle {
                                radius: Tokens.rounding.small
                                color: "transparent"
                                border.width: 1
                                border.color: titleField.activeFocus ? root.accent : root.outline
                            }

                            onAccepted: root.addEvent()
                        }

                        TextField {
                            id: timeField

                            Layout.preferredWidth: 64
                            placeholderText: "HH:MM"
                            color: root.foreground
                            placeholderTextColor: root.muted
                            font: Tokens.font.label.medium
                            background: Rectangle {
                                radius: Tokens.rounding.small
                                color: "transparent"
                                border.width: 1
                                border.color: timeField.activeFocus ? root.accent : root.outline
                            }

                            onAccepted: root.addEvent()
                        }

                        PillButton {
                            label: "+"
                            primary: true
                            onClicked: root.addEvent()
                        }
                    }
                }
            }
        }
    }
}
