import "navpane"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus

ColumnLayout {
    id: root

    required property NexusState nState

    spacing: Tokens.spacing.large

    function focusSearch(): void {
        searchField.forceActiveFocus();
    }

    SearchBar {
        id: searchField

        objectName: "nexusSearchField"
        Layout.fillWidth: true

        placeholderText: Tr.tr("Search settings")
        font: Tokens.font.body.large
        activeFocusOnTab: true
        Accessible.role: Accessible.EditableText
        Accessible.name: Tr.tr("Search settings")
        Accessible.description: Tr.tr("Type to filter pages and settings")
        Accessible.focusable: true
        Accessible.focused: activeFocus

        bg.color: Colours.tPalette.m3surfaceContainerLowest
        bg.border.color: activeFocus ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
        bg.border.width: activeFocus ? 2 : 1
        searchIcon.fontStyle: Tokens.font.icon.medium
        searchIcon.anchors.leftMargin: Tokens.padding.largeIncreased
        clearIcon.font: Tokens.font.icon.medium
        clearIcon.padding: Tokens.padding.extraSmall

        onTextChanged: {
            if (root.nState.searchQuery !== text)
                root.nState.setSearchQuery(text);
        }

        onAccepted: {
            if (locations.searchMode && locations.resultCount > 0)
                locations.activateResult(locations.selectedResult);
            else
                locations.focusPage(Math.max(0, Math.min(PageRegistry.pages.length - 1, root.nState.currentPageIdx)));
        }

        Keys.onDownPressed: event => {
            if (locations.searchMode)
                locations.focusFirstResult();
            else
                locations.focusPage(Math.max(0, Math.min(PageRegistry.pages.length - 1, root.nState.currentPageIdx)));
            event.accepted = true;
        }
        Keys.onEscapePressed: event => {
            if (text.length > 0) {
                root.nState.clearSearch();
                searchField.text = "";
                root.nState.searchOpen = false;
                searchField.forceActiveFocus();
            } else {
                root.nState.close();
            }
            event.accepted = true;
        }

        Behavior on bg.border.color {
            CAnim {}
        }
    }

    NavLocations {
        id: locations

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: -topMargin
        Layout.bottomMargin: -bottomMargin
        nState: root.nState

        onSearchCleared: root.focusSearch()
    }

    Connections {
        function onSearchQueryChanged(): void {
            if (searchField.text !== root.nState.searchQuery)
                searchField.text = root.nState.searchQuery;
        }

        target: root.nState
    }
}
