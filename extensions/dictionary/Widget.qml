pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// Offline dictionary. It reads the StarDict pack for the system language from
// the installed share tree or the user's pack directory; nothing here talks to
// the network.
Item {
    id: root

    property var api
    property bool active: true

    property string query: ""
    property string dataDir: ""
    property var results: []
    property bool searching: false
    property string status: ""
    property string statusKind: ""

    readonly property var themePalette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color foreground: root.themePalette ? root.themePalette.m3onSurface : "transparent"
    readonly property color muted: root.themePalette ? root.themePalette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.themePalette ? root.themePalette.m3primary : "transparent"
    readonly property color onAccent: root.themePalette ? root.themePalette.m3onPrimary : "transparent"
    readonly property color errorColour: root.themePalette ? root.themePalette.m3error : "transparent"
    readonly property color surface: root.themePalette ? root.themePalette.m3surfaceContainerLow : "transparent"
    readonly property color fieldColour: root.themePalette ? root.themePalette.m3surfaceContainerHigh : "transparent"
    readonly property color outline: root.themePalette ? root.themePalette.m3outlineVariant : "transparent"

    readonly property string dataHome: {
        const home = Quickshell.env("HOME") || "";
        return Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`;
    }
    readonly property string language: root.systemLanguage()
    readonly property string userDir: `${root.dataHome}/padilha/dictionary/${root.language}`
    readonly property string systemDir: `/usr/lib/maria-padilha/share/dictionaries/${root.language}`

    function systemLanguage(): string {
        const raw = Quickshell.env("LANG") || Quickshell.env("LC_MESSAGES") || "en_US.UTF-8";
        const code = raw.split(".")[0].replace(/_/g, "-").toLowerCase();
        if (code.indexOf("pt") === 0)
            return "pt";
        if (code.indexOf("en") === 0)
            return "en";
        return code.split("-")[0] || "en";
    }

    function languageName(): string {
        if (root.language === "pt")
            return Tr.tr("Portuguese");
        if (root.language === "en")
            return Tr.tr("English");
        return root.language;
    }

    function resolvePack(): void {
        root.dataDir = "";
        dirProc.command = [
            "sh", "-c",
            `for d in "$1" "$2"; do if [ -d "$d/dic" ]; then printf '%s' "$d"; exit 0; fi; done`,
            "sh", root.userDir, root.systemDir
        ];
        dirProc.running = true;
    }

    function handleDir(output: string): void {
        root.dataDir = output.trim();
        if (root.dataDir.length === 0) {
            root.statusKind = "error";
            root.status = Tr.tr("No dictionary pack is installed for %1.").arg(root.languageName());
        } else if (root.statusKind !== "error") {
            root.statusKind = "";
            root.status = "";
        }
    }

    function lookup(): void {
        const text = root.query.trim();
        if (text.length === 0) {
            root.results = [];
            root.statusKind = "";
            root.status = "";
            return;
        }
        if (root.dataDir.length === 0) {
            root.statusKind = "error";
            root.status = Tr.tr("No dictionary pack is installed for %1.").arg(root.languageName());
            return;
        }
        root.searching = true;
        root.statusKind = "";
        root.status = Tr.tr("Searching...");
        lookupProc.command = [
            "sdcv", "-n", "-j", "--utf8-input", "--utf8-output",
            "--data-dir", root.dataDir, text
        ];
        lookupProc.running = true;
    }

    function plainText(value: string): string {
        return String(value)
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<\/li>/gi, "\n")
            .replace(/<[^>]*>/g, "")
            .replace(/&nbsp;/g, " ")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&#39;/g, "'")
            .replace(/\n{3,}/g, "\n\n")
            .trim();
    }

    function handleLookup(code: int, output: string, errorOutput: string): void {
        root.searching = false;
        if (code === 127) {
            root.statusKind = "error";
            root.status = Tr.tr("The dictionary reader (sdcv) is not installed.");
            return;
        }
        if (code !== 0) {
            root.statusKind = "error";
            root.status = errorOutput.trim() || Tr.tr("The dictionary lookup failed.");
            return;
        }
        try {
            const data = JSON.parse(output);
            if (!Array.isArray(data) || data.length === 0) {
                root.results = [];
                root.statusKind = "";
                root.status = Tr.tr("No entry found.");
                return;
            }
            root.results = data.map(entry => ({
                dict: typeof entry.dict === "string" ? entry.dict : "",
                word: typeof entry.word === "string" ? entry.word : root.query,
                definition: root.plainText(entry.definition ?? "")
            }));
            root.statusKind = "";
            root.status = Tr.trN("%n entry", "%n entries", root.results.length);
        } catch (error) {
            root.statusKind = "error";
            root.status = Tr.tr("Could not read the dictionary output.");
        }
    }

    Component.onCompleted: root.resolvePack()

    Process {
        id: dirProc

        stdout: StdioCollector {
            id: dirOutput
        }

        onExited: root.handleDir(dirOutput.text)
    }

    Process {
        id: lookupProc

        stdout: StdioCollector {
            id: lookupOutput
        }

        stderr: StdioCollector {
            id: lookupError
        }

        onExited: code => Qt.callLater(() => root.handleLookup(code, lookupOutput.text, lookupError.text))
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Text {
                text: Tr.tr("Dictionary")
                color: root.foreground
                font: Tokens.font.body.large
            }

            Text {
                text: Tr.tr("System language: %1").arg(root.languageName())
                color: root.muted
                font: Tokens.font.label.medium
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "FreeDict · GPL-2.0-or-later"
                color: root.muted
                font: Tokens.font.label.small
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Input {
                id: search

                Layout.fillWidth: true
                placeholderText: Tr.tr("Type a word and press Enter")
                onTextEdited: root.query = text
                onAccepted: root.lookup()
            }

            ActionButton {
                label: Tr.tr("Search")
                primary: true
                onActivated: {
                    root.query = search.text;
                    root.lookup();
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.large
            color: root.surface
            border.width: 1
            border.color: root.outline

            Flickable {
                id: resultsView

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                visible: root.results.length > 0
                clip: true
                contentWidth: width
                contentHeight: resultsColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: resultsColumn

                    width: resultsView.width
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: root.results

                        delegate: Column {
                            id: result

                            required property var modelData

                            width: resultsColumn.width
                            spacing: 3

                            Text {
                                width: parent.width
                                text: result.modelData.word
                                color: root.foreground
                                font: Tokens.font.body.medium
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: text.length > 0
                                text: result.modelData.dict
                                color: root.muted
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: result.modelData.definition
                                color: root.foreground
                                font: Tokens.font.body.medium
                                wrapMode: Text.Wrap
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: root.outline
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - Tokens.padding.large * 2
                visible: root.results.length === 0
                text: root.status.length > 0 ? root.status : Tr.tr("Look up a word in the installed dictionary.")
                color: root.statusKind === "error" ? root.errorColour : root.muted
                font: Tokens.font.label.medium
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Text {
                Layout.fillWidth: true
                text: root.status
                color: root.statusKind === "error" ? root.errorColour : root.muted
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            Text {
                visible: root.searching
                text: Tr.tr("Searching...")
                color: root.muted
                font: Tokens.font.label.small
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
        implicitHeight: 38

        background: Rectangle {
            color: root.fieldColour
            radius: Tokens.rounding.small
            border.width: 1
            border.color: input.activeFocus ? root.accent : root.outline
        }
    }

    component ActionButton: Rectangle {
        id: button

        property string label
        property bool primary: false

        signal activated()

        implicitWidth: Math.max(72, labelText.implicitWidth + Tokens.padding.large * 2)
        implicitHeight: 38
        radius: Tokens.rounding.small
        color: button.primary ? root.accent : "transparent"
        border.width: button.primary ? 0 : button.activeFocus ? 2 : 1
        border.color: button.activeFocus ? root.accent : root.outline
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
            color: button.primary ? root.onAccent : root.foreground
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
