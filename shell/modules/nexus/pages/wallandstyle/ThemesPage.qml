pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Themes")
    isSubPage: true

    property var themes: []
    property string activeTheme: ""
    property string dayPath: ""
    property string nightPath: ""
    property string statusText: ""
    property bool statusIsError: false

    function basename(path: string): string {
        return String(path).split("/").pop() ?? "";
    }

    function refresh(): void {
        if (!listProc.running)
            listProc.running = true;
    }

    function applyTheme(themeId: string): void {
        if (useProc.running)
            return;
        statusIsError = false;
        statusText = Tr.tr("Applying theme…");
        useProc.command = ["padilha", "theme", "use", themeId];
        useProc.running = true;
    }

    function createTheme(): void {
        if (addProc.running)
            return;
        if (nameField.text.trim() === "" || dayPath === "" || nightPath === "") {
            statusIsError = true;
            statusText = Tr.tr("Name the theme and choose both images first");
            return;
        }
        statusIsError = false;
        statusText = Tr.tr("Adding theme…");
        addProc.command = [
            "padilha", "theme", "add",
            "--name", nameField.text.trim(),
            "--day", dayPath,
            "--night", nightPath
        ];
        addProc.running = true;
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("A theme pairs one wallpaper for the day with one for the night. The active theme changes automatically with the palette schedule.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        SectionHeader {
            first: true
            text: Tr.tr("Installed themes")
        }

        Repeater {
            model: root.themes

            NavRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === root.themes.length - 1
                icon: modelData.id === root.activeTheme ? "check_circle" : "wb_twilight"
                text: modelData.name
                subtext: Tr.tr("Day: %1 · Night: %2")
                    .arg(root.basename(modelData.day))
                    .arg(root.basename(modelData.night))
                onClicked: root.applyTheme(modelData.id)
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.themes.length === 0
            text: Tr.tr("No themes yet. Add a pair below.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        SectionHeader {
            text: Tr.tr("Add a theme")
        }

        StyledTextField {
            id: nameField

            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            placeholderText: Tr.tr("Theme name")
            leadingIcon: "label"
        }

        ButtonRow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            spacing: Tokens.spacing.small

            IconTextButton {
                text: root.dayPath === "" ? Tr.tr("Choose day image") : root.basename(root.dayPath)
                icon: "light_mode"
                type: IconTextButton.Tonal
                onClicked: dayDialog.open()
            }

            IconTextButton {
                text: root.nightPath === "" ? Tr.tr("Choose night image") : root.basename(root.nightPath)
                icon: "dark_mode"
                type: IconTextButton.Tonal
                onClicked: nightDialog.open()
            }

            IconTextButton {
                text: Tr.tr("Add")
                icon: "add"
                type: IconTextButton.Filled
                onClicked: root.createTheme()
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: root.statusText !== ""
            text: root.statusText
            color: root.statusIsError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }
        Item {
            id: dialogHost

            visible: false
            width: 0
            height: 0

        FileDialog {
            id: dayDialog

            title: Tr.tr("Select the day wallpaper")
            filterLabel: Tr.tr("Image files")
            filters: Images.validImageExtensions
            onAccepted: path => {
                root.dayPath = path;
                if (nameField.text.trim() === "")
                    nameField.text = root.basename(path).replace(/\.[^.]+$/, "");
            }
        }

        FileDialog {
            id: nightDialog

            title: Tr.tr("Select the night wallpaper")
            filterLabel: Tr.tr("Image files")
            filters: Images.validImageExtensions
            onAccepted: path => {
                root.nightPath = path;
            }
        }
                Process {
            id: listProc

            command: ["padilha", "theme", "list", "--json"]
            stdout: StdioCollector {
                id: listOutput

                onStreamFinished: {
                    try {
                        const data = JSON.parse(listOutput.text);
                        root.themes = data.themes ?? [];
                        root.activeTheme = data.active ?? "";
                    } catch (e) {
                        root.themes = [];
                        root.activeTheme = "";
                    }
                }
            }
        }

        Process {
            id: useProc

            stderr: StdioCollector {
                id: useError
            }
            onExited: code => {
                if (code === 0) {
                    root.statusIsError = false;
                    root.statusText = Tr.tr("Theme applied");
                    root.refresh();
                } else {
                    root.statusIsError = true;
                    root.statusText = useError.text.trim() || Tr.tr("Could not apply the theme");
                }
            }
        }

        Process {
            id: addProc

            stderr: StdioCollector {
                id: addError
            }
            onExited: code => {
                if (code === 0) {
                    root.statusIsError = false;
                    root.statusText = Tr.tr("Theme added");
                    root.dayPath = "";
                    root.nightPath = "";
                    nameField.text = "";
                    root.refresh();
                } else {
                    root.statusIsError = true;
                    root.statusText = addError.text.trim() || Tr.tr("Could not add the theme");
                }
            }
        }
}
    }


}
