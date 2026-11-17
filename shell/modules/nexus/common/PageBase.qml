pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus
import "../search/FocusNavigation.js" as FocusNavigation

ColumnLayout {
    id: root

    required property string title
    required property NexusState nState
    property bool isSubPage
    readonly property int cappedWidth: Math.min(Tokens.sizes.nexus.maxContentWidth, width)
    readonly property alias flickable: flickable

    default property Item contentChild

    objectName: "nexusPageBase"
    focus: true
    spacing: Tokens.spacing.extraLargeIncreased

    function normalise(value: string): string {
        return SettingsSearch.normalise(value);
    }

    function collectRows(node: var, result: var): void {
        if (!node)
            return;

        if (node.settingsRow === true && node.visible)
            result.push(node);

        const children = node.children ?? [];
        for (let i = 0; i < children.length; i++) {
            const child = children[i];
            if (child.objectName !== "nexusSearchHighlight")
                root.collectRows(child, result);
        }
    }

    function rows(): var {
        const result = [];
        root.collectRows(root, result);
        return result;
    }

    function interactiveRows(): var {
        return root.rows().filter(row => row.settingsInteractive !== false && row.activeFocusOnTab === true && row.enabled !== false);
    }

    function focusedRow(): var {
        let item = QsWindow.window?.activeFocusItem ?? null;
        while (item && item !== root) {
            if (item.settingsRow === true)
                return item;
            item = item.parent;
        }
        return null;
    }

    function ensureVisible(item: var): void {
        if (!item)
            return;

        const position = item.mapToItem(flickable.contentItem, 0, 0);
        const top = position.y - Tokens.padding.small;
        const bottom = position.y + item.height + Tokens.padding.small;
        const viewTop = flickable.contentY + flickable.topMargin;
        const viewBottom = viewTop + flickable.height - flickable.topMargin - flickable.bottomMargin;

        if (top < viewTop)
            flickable.contentY = Math.max(-flickable.topMargin, top - flickable.topMargin);
        else if (bottom > viewBottom)
            flickable.contentY = Math.min(flickable.contentHeight + flickable.bottomMargin - flickable.height, bottom - flickable.height + flickable.bottomMargin);
    }

    function moveFocus(delta: int): bool {
        const list = root.interactiveRows();
        if (list.length === 0)
            return false;

        const next = FocusNavigation.stepInList(list, root.focusedRow(), delta);
        const target = list[next];
        if (!target)
            return false;

        target.forceActiveFocus();
        root.ensureVisible(target);
        return true;
    }

    function findSetting(target: var): var {
        if (!target || root.nState.searchTarget !== target || target.pageIdx !== root.nState.currentPageIdx)
            return null;

        if (target.kind === "page")
            return root.normalise(root.title) === root.normalise(target.label) ? titleText : null;

        const wantedLabel = root.normalise(target.label);
        const wantedDescription = root.normalise(target.description);
        let best = null;
        let bestScore = 0;

        for (const row of root.rows()) {
            const label = root.normalise(row.settingsLabel ?? row.text ?? row.label ?? "");
            if (!label)
                continue;

            let score = 0;
            if (label === wantedLabel)
                score += 100;
            else if (label.indexOf(wantedLabel) >= 0 || wantedLabel.indexOf(label) >= 0)
                score += 45;
            else
                continue;

            const description = root.normalise(row.settingsDescription ?? row.subtext ?? "");
            if (wantedDescription && description === wantedDescription)
                score += 25;
            else if (wantedDescription && description.indexOf(wantedDescription) >= 0)
                score += 10;

            if (score > bestScore) {
                best = row;
                bestScore = score;
            }
        }

        return best;
    }

    function showHighlight(item: var): void {
        if (!item)
            return;

        if (highlightMarker) {
            highlightMarker.destroy();
            highlightMarker = null;
        }

        highlightMarker = highlightComp.createObject(item, {
            highlightTarget: item
        });

        if (item.settingsInteractive !== false && item.activeFocusOnTab === true)
            item.forceActiveFocus();
        root.ensureVisible(item);
    }

    function applySearchTarget(): void {
        const target = root.findSetting(root.nState.searchTarget);
        if (target)
            root.showHighlight(target);
    }

    property var highlightMarker: null

    Component.onCompleted: Qt.callLater(root.applySearchTarget)

    Connections {
        function onSearchHighlightRequestChanged(): void {
            Qt.callLater(root.applySearchTarget);
        }

        target: root.nState
    }

    Keys.onUpPressed: event => {
        if (root.moveFocus(-1))
            event.accepted = true;
    }
    Keys.onDownPressed: event => {
        if (root.moveFocus(1))
            event.accepted = true;
    }

    Component {
        id: highlightComp

        Rectangle {
            id: marker

            required property Item highlightTarget

            objectName: "nexusSearchHighlight"
            anchors.fill: highlightTarget
            anchors.margins: -2
            z: 100
            radius: Tokens.rounding.medium
            color: Qt.alpha(Colours.palette.m3primary, 0.14)
            border.width: 2
            border.color: Colours.palette.m3primary
            opacity: 0

            NumberAnimation on opacity {
                from: 0
                to: 1
                duration: Tokens.anim.durations.expressiveFastEffects
                easing: Tokens.anim.expressiveFastEffects
            }

            Timer {
                interval: 2600
                running: true
                onTriggered: fadeOut.start()
            }

            NumberAnimation {
                id: fadeOut

                target: marker
                property: "opacity"
                to: 0
                duration: Tokens.anim.durations.expressiveSlowEffects
                easing: Tokens.anim.expressiveSlowEffects
                onFinished: {
                    if (root.highlightMarker === marker)
                        root.highlightMarker = null;
                    marker.destroy();
                }
            }
        }
    }

    MouseArea { // Prevent clicks from reaching flickable
        z: 1
        implicitWidth: header.implicitWidth
        implicitHeight: header.implicitHeight - Layout.bottomMargin
        Layout.bottomMargin: -flickable.topMargin // Extra height to block clicks on flickable top margin
        onClicked: focus = true

        RowLayout {
            id: header

            spacing: Tokens.spacing.largeIncreased

            Loader {
                visible: active
                active: root.isSubPage
                asynchronous: true
                sourceComponent: IconButton {
                    icon: "arrow_back"
                    font: Tokens.font.icon.medium
                    type: IconButton.Tonal
                    isRound: true
                    inactiveColour: Colours.tPalette.m3surfaceContainerHigh
                    inactiveOnColour: Colours.palette.m3onSurfaceVariant
                    onClicked: root.nState.closeSubPage()
                }
            }

            StyledText {
                id: titleText

                Layout.fillWidth: true
                text: root.title
                font: Tokens.font.title.large
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    VerticalFadeFlickable {
        id: flickable

        Layout.fillWidth: true
        Layout.fillHeight: true

        Layout.topMargin: -topMargin
        topMargin: Tokens.padding.large
        bottomMargin: Tokens.padding.extraLarge

        contentHeight: root.contentChild?.implicitHeight ?? 0
        contentItem.children: [root.contentChild]

        TapHandler {
            onTapped: flickable.focus = true
        }
    }
}
