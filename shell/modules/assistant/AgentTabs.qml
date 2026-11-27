import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Templates
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property var agents: []
    property string homeId: ""
    property string activeId: ""
    property bool viewingAgent: false

    signal homeRequested()
    signal agentRequested(string id)

    readonly property var tabsModel: {
        const out = [{
                id: root.homeId,
                title: Tr.tr("OS maintenance"),
                home: true,
                owned: false,
                iconName: "home"
            }];
        for (const agent of root.agents) {
            out.push({
                id: agent.id,
                title: agent.label || ("Agent " + String(agent.id).substring(0, 8)),
                home: false,
                owned: !!agent.owned,
                iconName: "smart_toy"
            });
        }
        return out;
    }

    readonly property int currentIndex: {
        const index = root.tabsModel.findIndex(item => item.id === root.activeId && (root.viewingAgent ? !item.home : item.home));
        return index >= 0 ? index : 0;
    }

    visible: true
    implicitHeight: bar.implicitHeight + bar.anchors.topMargin + indicator.implicitHeight + indicator.anchors.topMargin

    TabBar {
        id: bar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Tokens.sizes.dashboard.tabIndicatorSpacing

        currentIndex: root.currentIndex
        onCurrentIndexChanged: {
            if (currentIndex !== root.currentIndex)
                root.activate(currentIndex);
        }

        implicitHeight: contentHeight
        background: null
        contentItem: RowLayout {
            spacing: 0

            Repeater {
                model: bar.contentModel
            }
        }

        Repeater {
            model: ScriptModel {
                values: root.tabsModel
            }

            delegate: Tab {
                required property var modelData

                iconName: modelData.iconName
                text: modelData.title
            }
        }
    }

    Item {
        id: indicator

        anchors.top: bar.bottom
        anchors.topMargin: Tokens.sizes.dashboard.tabIndicatorSpacing

        readonly property Item currentTab: bar.currentItem
        readonly property real fallbackWidth: bar.count > 0 ? root.width / bar.count : root.width

        implicitWidth: currentTab?.width ?? fallbackWidth
        implicitHeight: Tokens.sizes.dashboard.tabIndicatorHeight

        x: {
            if (!currentTab)
                return fallbackWidth * bar.currentIndex;
            const origin = currentTab.mapToItem(root, 0, 0);
            return origin.x + (currentTab.width - implicitWidth) / 2;
        }

        clip: true

        StyledRect {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: parent.implicitHeight * 2

            color: Colours.palette.m3primary
            radius: Tokens.rounding.full
        }

        Behavior on x {
            Anim {}
        }

        Behavior on implicitWidth {
            Anim {}
        }
    }

    function activate(index: int): void {
        const tab = root.tabsModel[index];
        if (!tab)
            return;
        if (tab.home)
            root.homeRequested();
        else
            root.agentRequested(tab.id);
    }

    component Tab: TabButton {
        id: tab

        required property string iconName
        readonly property bool current: TabBar.tabBar.currentItem === this

        focusPolicy: Qt.StrongFocus
        activeFocusOnTab: true

        Accessible.role: Accessible.PageTab
        Accessible.name: tab.text
        Accessible.selected: tab.current
        Accessible.focusable: true
        Accessible.focused: activeFocus
        Accessible.onPressAction: root.activate(tab.TabBar.index)

        Keys.onReturnPressed: root.activate(tab.TabBar.index)
        Keys.onEnterPressed: root.activate(tab.TabBar.index)
        Keys.onSpacePressed: root.activate(tab.TabBar.index)

        Layout.fillWidth: root.tabsModel.length > 1
        Layout.preferredWidth: root.tabsModel.length > 1 ? 1 : implicitWidth
        Layout.minimumWidth: Tokens.sizes.bar.innerWidth
        implicitWidth: implicitContentWidth
        implicitHeight: implicitContentHeight
        background: null

        contentItem: Item {
            id: content

            implicitWidth: Math.max(icon.implicitWidth, label.implicitWidth) + Tokens.padding.extraSmall * 2
            implicitHeight: icon.implicitHeight + label.implicitHeight + Tokens.spacing.extraSmall

            StateLayer {
                anchors.fill: undefined
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: parent.height + Tokens.sizes.dashboard.tabIndicatorSpacing * 2

                radius: Tokens.rounding.medium
                color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurface
                onClicked: root.activate(tab.TabBar.index)
            }

            MaterialIcon {
                id: icon

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: label.top
                anchors.bottomMargin: Tokens.spacing.extraSmall

                text: tab.iconName
                color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fill: tab.current ? 1 : 0
                fontStyle: Tokens.font.icon.medium

                Behavior on fill {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            StyledText {
                id: label

                readonly property real availableWidth: Math.max(0, tab.width - Tokens.padding.small * 2)

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom

                width: Math.min(implicitWidth, availableWidth)
                text: tab.text
                color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }
}
