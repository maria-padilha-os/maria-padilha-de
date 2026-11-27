import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
                owned: false
            }];
        for (const agent of root.agents) {
            out.push({
                id: agent.id,
                title: agent.label || ("Agent " + String(agent.id).substring(0, 8)),
                home: false,
                owned: !!agent.owned
            });
        }
        return out;
    }

    visible: true
    readonly property int tabBarHeight: 40
    implicitHeight: tabBarHeight + Tokens.sizes.dashboard.tabIndicatorSpacing + Tokens.sizes.dashboard.tabIndicatorHeight
    property Item activeTabItem: null

    ListView {
        id: list

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.tabBarHeight
        orientation: ListView.Horizontal
        spacing: Tokens.spacing.extraSmall
        clip: true
        model: root.tabsModel
        boundsBehavior: Flickable.StopAtBounds

        delegate: ItemDelegate {
            id: tab

            required property var modelData

            readonly property bool active: modelData.home ? (!root.viewingAgent && modelData.id === root.activeId) : (root.viewingAgent && modelData.id === root.activeId)

            width: Math.min(190, Math.max(120, label.implicitWidth + 36))
            height: list.height
            padding: 0
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            activeFocusOnTab: true

            Accessible.role: Accessible.PageTab
            Accessible.name: modelData.title
            Accessible.selected: tab.active
            Accessible.focusable: true
            Accessible.focused: activeFocus
            Accessible.onPressAction: tab.activate()

            function activate(): void {
                if (modelData.home)
                    root.homeRequested();
                else
                    root.agentRequested(modelData.id);
            }

            onClicked: activate()
            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()

            background: null

            contentItem: Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.home ? "home" : "smart_toy"
                        color: tab.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fill: tab.active ? 1 : 0
                        fontStyle: Tokens.font.icon.medium

                        Behavior on color {
                            Anim {}
                        }
                        Behavior on fill {
                            Anim {}
                        }
                    }

                    StyledText {
                        id: label

                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: tab.width - 12
                        text: modelData.title
                        color: tab.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.builders.small.scale(0.9).build()
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                StyledRect {
                    visible: modelData.owned
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    implicitWidth: 7
                    implicitHeight: 7
                    radius: 3.5
                    color: Colours.palette.m3primary
                }
            }
        }
    }

    // Same gap and height as the dashboard: the indicator lives below the
    // tab bar, not inside the tab content where it reads as an underline.
    Item {
        id: indicator

        anchors.top: list.bottom
        anchors.topMargin: Tokens.sizes.dashboard.tabIndicatorSpacing
        height: Tokens.sizes.dashboard.tabIndicatorHeight
        visible: root.activeTabItem !== null
        width: root.activeTabItem ? root.activeTabItem.width : 0
        x: root.activeTabItem ? root.activeTabItem.x - list.contentX + (root.activeTabItem.width - width) / 2 : 0

        StyledRect {
            anchors.fill: parent
            color: Colours.palette.m3primary
            radius: Tokens.rounding.full
        }

        Behavior on x {
            Anim {}
        }

        Behavior on width {
            Anim {}
        }
    }

    readonly property int activeIndex: tabsModel.findIndex(item => item.id === root.activeId && (root.viewingAgent ? !item.home : item.home))

    function syncIndicator(): void {
        root.activeTabItem = root.activeIndex >= 0 ? list.itemAtIndex(root.activeIndex) : null;
    }

    function syncPosition(): void {
        if (root.activeIndex >= 0)
            Qt.callLater(() => list.positionViewAtIndex(root.activeIndex, ListView.Contain));
    }

    Component.onCompleted: Qt.callLater(syncIndicator)
    onActiveIdChanged: {
        syncPosition();
        Qt.callLater(syncIndicator);
    }
    onViewingAgentChanged: {
        syncPosition();
        Qt.callLater(syncIndicator);
    }
    onTabsModelChanged: Qt.callLater(syncIndicator)
    onWidthChanged: Qt.callLater(syncIndicator)
}
