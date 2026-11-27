import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    property string query: ""
    property string filterMode: "all"
    property real pendingScrollY: -1

    readonly property var filteredExtensions: Extensions.filtered(root.query, root.filterMode)
    readonly property bool hasInstalled: Extensions.list.length > 0
    readonly property bool hasVisible: root.filteredExtensions.length > 0

    function holdScroll(): void {
        root.pendingScrollY = root.flickable.contentY;
    }

    function restoreScroll(): void {
        const y = root.pendingScrollY;
        if (y < 0)
            return;
        root.pendingScrollY = -1;
        Qt.callLater(() => {
            const maxY = Math.max(-root.flickable.topMargin, root.flickable.contentHeight + root.flickable.bottomMargin - root.flickable.height);
            root.flickable.contentY = Math.max(-root.flickable.topMargin, Math.min(y, maxY));
        });
    }
    readonly property var filterModes: [
        {
            key: "all",
            label: Tr.tr("All"),
            icon: "apps"
        },
        {
            key: "enabled",
            label: Tr.tr("Enabled"),
            icon: "toggle_on"
        },
        {
            key: "disabled",
            label: Tr.tr("Disabled"),
            icon: "toggle_off"
        },
        {
            key: "issues",
            label: Tr.tr("Needs attention"),
            icon: "warning"
        }
    ]

    title: Tr.tr("Extensions")

    Component.onCompleted: {
        if (Extensions.list.length === 0)
            Extensions.refresh();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.extraSmall
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: {
                    if (Extensions.loading)
                        return Tr.tr("Looking for extensions…");
                    const total = Tr.trN("%n extension", "%n extensions", Extensions.list.length);
                    if (root.query.length > 0 || root.filterMode !== "all")
                        return Tr.tr("%1 of %2").arg(root.filteredExtensions.length).arg(total);
                    return total;
                }
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Tonal
                isRound: true
                accessibleName: Tr.tr("Refresh extensions")
                enabled: !Extensions.loading
                onClicked: Extensions.refresh()
            }
        }

        SearchBar {
            id: searchField

            Layout.fillWidth: true
            placeholderText: Tr.tr("Search by name, id, description, shortcut or permission")
            font: Tokens.font.body.large
            onTextChanged: root.query = text
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: root.filterModes

                delegate: IconTextButton {
                    required property var modelData

                    text: modelData.label
                    icon: modelData.icon
                    type: root.filterMode === modelData.key ? IconTextButton.Filled : IconTextButton.Tonal
                    onClicked: root.filterMode = modelData.key
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: Extensions.problemCount > 0
            text: Tr.trN("%n extension needs attention. Problems are shown on its card and it stays listed.", "%n extensions need attention. Problems are shown on their cards and they stay listed.", Extensions.problemCount)
            color: Colours.palette.m3error
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.hasInstalled
            text: Tr.tr("Enabled extensions appear as tabs in the top panel, after Weather. Toggling one takes effect immediately; nothing is installed or downloaded automatically.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        SectionHeader {
            visible: root.hasVisible
            text: root.query.length > 0 || root.filterMode !== "all" ? Tr.tr("Matches") : Tr.tr("Installed")
        }

        Repeater {
            model: root.filteredExtensions

            delegate: ExtensionCard {
                required property var modelData
                required property int index

                extension: modelData
                onToggleRequested: enabled => {
                    root.holdScroll();
                    Extensions.setTabEnabled(modelData.id, enabled);
                    root.restoreScroll();
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large
            visible: !Extensions.loading && !root.hasInstalled
            text: Tr.tr("No extensions installed. An extension is a folder under ~/.config/padilha/extensions with an extension.json manifest and a Tab.qml tab. Add one yourself; the shell never downloads or installs extensions.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large
            visible: !Extensions.loading && root.hasInstalled && !root.hasVisible
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("No extensions match this search or filter.")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            IconTextButton {
                text: Tr.tr("Clear search and filters")
                icon: "filter_alt_off"
                type: IconTextButton.Tonal
                onClicked: {
                    root.query = "";
                    root.filterMode = "all";
                    searchField.clear();
                }
            }
        }
    }
}
