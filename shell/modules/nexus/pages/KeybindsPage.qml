import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    property var sections: []
    property bool loading: false

    readonly property int rowCount: sections.reduce((total, section) => total + section.rows.length, 0)

    title: Tr.tr("Keybinds")

    function refresh(): void {
        loading = true;
        sections = [];
        readProc.running = true;
    }

    function parse(markdown: string): var {
        const result = [];
        let current = null;

        for (const raw of markdown.split("\n")) {
            const line = raw.trim();
            if (line.startsWith("## ")) {
                current = {
                    title: line.slice(3).trim(),
                    rows: []
                };
                result.push(current);
                continue;
            }

            if (!current || !line.startsWith("|"))
                continue;

            const cells = line.split("|").slice(1, -1).map(cell => cell.trim());
            if (cells.length < 2)
                continue;
            if (/^:?-{2,}:?$/.test(cells[0]))
                continue;
            if (cells[0].toLowerCase() === "keys")
                continue;

            const clean = value => value.replace(/`/g, "").replace(/\*\*/g, "");
            current.rows.push({
                keys: clean(cells[0]),
                action: clean(cells[1])
            });
        }

        return result.filter(section => section.rows.length > 0);
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: root.loading ? Tr.tr("Reading keybinds…") : Tr.tr("%1 shortcuts").arg(root.rowCount)
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Tonal
                isRound: true
                enabled: !root.loading
                onClicked: root.refresh()
            }
        }

        Repeater {
            model: root.sections

            delegate: ColumnLayout {
                id: section

                required property var modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    text: section.modelData.title
                }

                Repeater {
                    model: section.modelData.rows

                    delegate: InfoRow {
                        required property var modelData
                        required property int index

                        first: index === 0
                        last: index === section.modelData.rows.length - 1
                        label: modelData.action
                        value: modelData.keys
                    }
                }
            }
        }

        // Non-visual: PageBase's default property is an Item.
        Process {
            id: readProc

            command: [
                "sh", "-c",
                `cat "$1" 2>/dev/null || cat /usr/lib/maria-padilha/share/KEYBINDS.md 2>/dev/null || cat /usr/lib/lilith/share/KEYBINDS.md 2>/dev/null`,
                "sh", `${Quickshell.shellDir}/../KEYBINDS.md`
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    root.sections = root.parse(text);
                    root.loading = false;
                }
            }

            onExited: root.loading = false
        }
    }
}
