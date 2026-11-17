pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services
import qs.modules.nexus
import "../search/FocusNavigation.js" as FocusNavigation

VerticalFadeFlickable {
    id: root

    required property NexusState nState

    readonly property bool searchMode: root.nState.searchQuery.trim().length > 0
    readonly property var results: root.searchMode ? SettingsSearch.search(root.nState.searchQuery, SettingsSearch.resultLimit) : []
    readonly property int resultCount: root.results.length
    property int selectedResult

    signal searchCleared

    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.large
    contentHeight: content.implicitHeight

    function clampResult(index: int): int {
        return FocusNavigation.clamp(index, root.resultCount);
    }

    function focusPage(index: int): void {
        if (index < 0 || index >= PageRegistry.pages.length)
            return;
        const item = pageRepeater.itemAt(index);
        if (item) {
            item.forceActiveFocus();
            root.scrollTo(item);
        }
    }

    function focusSearchResult(index: int): void {
        const clamped = root.clampResult(index);
        if (clamped < 0)
            return;
        root.selectedResult = clamped;
        const item = resultRepeater.itemAt(clamped);
        if (item) {
            item.forceActiveFocus();
            root.scrollTo(item);
        }
    }

    function focusFirstResult(): void {
        root.focusSearchResult(root.selectedResult);
    }

    function activatePage(index: int): void {
        if (index >= 0 && index < PageRegistry.pages.length)
            root.nState.currentPageIdx = index;
    }

    function activateResult(index: int): void {
        const result = root.results[index];
        if (result)
            root.nState.navigateToSearchResult(result);
    }

    function scrollTo(item: var): void {
        if (!item)
            return;
        const position = item.mapToItem(root.contentItem, 0, 0);
        const top = position.y - Tokens.padding.small;
        const bottom = position.y + item.height + Tokens.padding.small;
        const viewTop = root.contentY + root.topMargin;
        const viewBottom = viewTop + root.height - root.topMargin - root.bottomMargin;

        if (top < viewTop)
            root.contentY = Math.max(-root.topMargin, top - root.topMargin);
        else if (bottom > viewBottom)
            root.contentY = Math.min(root.contentHeight + root.bottomMargin - root.height, bottom - root.height + root.bottomMargin);
    }

    Connections {
        function onSearchQueryChanged(): void {
            root.selectedResult = 0;
        }

        target: root.nState
    }

    TapHandler {
        onTapped: root.focus = true
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.extraSmall

        Repeater {
            id: pageRepeater

            model: root.searchMode ? [] : PageRegistry.pages

            StyledRect {
                id: pageItem

                required property var modelData
                required property int index

                readonly property bool isCurrentPage: index === root.nState.currentPageIdx
                readonly property bool isCategoryStart: index === 0 || PageRegistry.pages[index - 1].category !== modelData.category
                readonly property bool isCategoryEnd: index === pageRepeater.count - 1 || PageRegistry.pages[index + 1].category !== modelData.category

                objectName: "nexusPageItem_" + index
                Layout.fillWidth: true
                Layout.topMargin: index !== 0 && isCategoryStart ? Tokens.spacing.medium : 0
                implicitHeight: {
                    const h = layout.implicitHeight + layout.anchors.margins * 2;
                    return h % 2 === 0 ? h : h + 1;
                }
                activeFocusOnTab: true
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.label
                Accessible.description: modelData.description
                Accessible.selected: isCurrentPage
                Accessible.focusable: true
                Accessible.focused: activeFocus
                Accessible.onPressAction: root.activatePage(index)

                Keys.onReturnPressed: root.activatePage(index)
                Keys.onEnterPressed: root.activatePage(index)
                Keys.onSpacePressed: root.activatePage(index)
                Keys.onUpPressed: root.focusPage(index - 1)
                Keys.onDownPressed: root.focusPage(index + 1)
                Keys.onEscapePressed: {
                    if (root.searchMode) {
                        root.nState.clearSearch();
                        root.searchCleared();
                    } else {
                        root.nState.close();
                    }
                }

                color: isCurrentPage ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                topLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryStart ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                topRightRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryStart ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                bottomLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryEnd ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                bottomRightRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryEnd ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

                RadiusBehavior on topLeftRadius {}
                RadiusBehavior on topRightRadius {}
                RadiusBehavior on bottomLeftRadius {}
                RadiusBehavior on bottomRightRadius {}

                FocusRing {
                    target: pageItem
                    colour: Colours.palette.m3primary
                    radius: pageItem.radius
                    margin: -1
                }

                StateLayer {
                    id: stateLayer

                    anchors.fill: parent
                    topLeftRadius: parent.topLeftRadius
                    topRightRadius: parent.topRightRadius
                    bottomLeftRadius: parent.bottomLeftRadius
                    bottomRightRadius: parent.bottomRightRadius

                    onClicked: {
                        pageItem.forceActiveFocus();
                        root.activatePage(pageItem.index);
                    }
                }

                RowLayout {
                    id: layout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        Layout.fillHeight: true
                        Layout.topMargin: -1
                        Layout.bottomMargin: -1
                        implicitWidth: height

                        radius: Tokens.rounding.full
                        color: pageItem.isCurrentPage ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1

                            text: pageItem.modelData.icon
                            color: pageItem.isCurrentPage ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                            grade: 25
                            fill: pageItem.modelData.noFill ? 0 : 1
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: pageItem.modelData.label
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: pageItem.modelData.description
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }
            }
        }

        Repeater {
            id: resultRepeater

            model: root.searchMode ? root.results : []

            StyledRect {
                id: resultItem

                required property var modelData
                required property int index

                readonly property bool isSelected: index === root.selectedResult
                readonly property bool isPage: modelData.kind === "page"
                readonly property string breadcrumb: modelData.subPageIdx >= 0 ? `${modelData.pageTitle} › ${modelData.label}` : modelData.pageTitle

                objectName: "nexusSearchResult_" + index
                Layout.fillWidth: true
                implicitHeight: resultLayout.implicitHeight + Tokens.padding.medium * 2
                activeFocusOnTab: true
                color: isSelected ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                radius: Tokens.rounding.large
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.label
                Accessible.description: modelData.description
                Accessible.selected: isSelected
                Accessible.focusable: true
                Accessible.focused: activeFocus
                Accessible.onPressAction: root.activateResult(index)

                Keys.onReturnPressed: root.activateResult(index)
                Keys.onEnterPressed: root.activateResult(index)
                Keys.onSpacePressed: root.activateResult(index)
                Keys.onUpPressed: root.focusSearchResult(index - 1)
                Keys.onDownPressed: root.focusSearchResult(index + 1)
                Keys.onLeftPressed: root.searchCleared()
                Keys.onEscapePressed: {
                    root.nState.clearSearch();
                    root.searchCleared();
                }

                onActiveFocusChanged: {
                    if (activeFocus)
                        root.selectedResult = index;
                }

                FocusRing {
                    target: resultItem
                    colour: Colours.palette.m3primary
                    radius: resultItem.radius
                    margin: -1
                }

                StateLayer {
                    anchors.fill: parent
                    topLeftRadius: resultItem.topLeftRadius
                    topRightRadius: resultItem.topRightRadius
                    bottomLeftRadius: resultItem.bottomLeftRadius
                    bottomRightRadius: resultItem.bottomRightRadius

                    onClicked: {
                        resultItem.forceActiveFocus();
                        root.activateResult(resultItem.index);
                    }
                }

                RowLayout {
                    id: resultLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: resultItem.isPage ? (PageRegistry.pages[resultItem.modelData.pageIdx]?.icon ?? "description") : "tune"
                        color: resultItem.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: resultItem.modelData.label
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: resultItem.modelData.description
                            visible: text.length > 0
                            color: resultItem.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: resultItem.breadcrumb
                            visible: resultItem.modelData.kind !== "page"
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    MaterialIcon {
                        text: "keyboard_return"
                        visible: resultItem.isSelected
                        color: resultItem.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                    }
                }
            }
        }

        StyledText {
            objectName: "nexusNoResults"

            Layout.fillWidth: true
            Layout.topMargin: Tokens.padding.large
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            visible: root.searchMode && root.resultCount === 0
            text: Tr.tr("No settings found")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    component RadiusBehavior: Behavior {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
