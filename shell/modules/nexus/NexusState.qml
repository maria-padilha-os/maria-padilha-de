import QtQuick
import Quickshell
import Quickshell.Bluetooth

QtObject {
    property ShellScreen screen
    property bool isWindow
    property bool animatingContainer
    property int currentPageIdx
    property list<int> subPageIdxStack
    property bool searchOpen
    property string searchQuery
    property var searchTarget
    property int searchHighlightRequest

    property string selectedWallpaperCategory
    property BluetoothDevice selectedBtDevice
    property DesktopEntry selectedApp
    property int editingVpnIndex: -1
    property string selectedNetworkSsid
    property string selectedEthernetInterface
    property bool networkDetailsFromSaved

    signal close
    signal subPageOpened(idx: int)
    signal subPageClosed
    signal pageResetRequested

    function setSearchQuery(query: string): void {
        if (searchQuery === query)
            return;
        searchQuery = query;
        searchOpen = query.trim().length > 0;
        if (searchOpen)
            searchTarget = null;
    }

    function clearSearch(): void {
        searchQuery = "";
        searchOpen = false;
    }

    function navigateToSearchResult(result: var): void {
        if (!result)
            return;

        const target = result.entry ?? result;
        const samePage = currentPageIdx === target.pageIdx;

        if (samePage) {
            searchTarget = target;
            const currentSubPage = subPageIdxStack.length > 0 ? subPageIdxStack[subPageIdxStack.length - 1] : -1;
            if (currentSubPage !== target.subPageIdx) {
                subPageIdxStack = target.subPageIdx >= 0 ? [target.subPageIdx] : [];
                pageResetRequested();
            }
        } else {
            currentPageIdx = target.pageIdx;
            subPageIdxStack = target.subPageIdx >= 0 ? [target.subPageIdx] : [];
            searchTarget = target;
        }

        searchQuery = "";
        searchOpen = false;
        searchHighlightRequest++;
    }

    function openSubPage(idx: int): void {
        subPageIdxStack.push(idx);
        subPageOpened(idx);
    }

    function closeSubPage(): void {
        subPageClosed();
        subPageIdxStack.pop();
    }

    onCurrentPageIdxChanged: {
        subPageIdxStack.length = 0;
        searchTarget = null;
    }
    onSearchQueryChanged: searchOpen = searchQuery.trim().length > 0
}
