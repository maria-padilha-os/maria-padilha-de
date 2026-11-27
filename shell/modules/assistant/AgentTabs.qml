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
    implicitHeight: 58

    ListView {
        id: list

        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: Tokens.spacing.extraSmall
        clip: true
        model: root.tabsModel
        boundsBehavior: Flickable.StopAtBounds

        delegate: ItemDelegate {
            id: tab

            required property var modelData

            readonly property bool active: modelData.home ? (!root.viewingAgent && modelData.id === root.activeId) : (root.viewingAgent && modelData.id === root.activeId)

            width: Math.min(190, Math.max(94, label.implicitWidth + 36))
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

            background: StyledRect {
                radius: Tokens.rounding.medium
                color: tab.active ? Qt.alpha(Colours.palette.m3primary, 0.10) : (tab.hovered ? Colours.tPalette.m3surfaceContainerHighest : "transparent")

                Behavior on color {
                    Anim {}
                }
            }

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

                        ToolTip.visible: tab.hovered && label.truncated
                        ToolTip.text: modelData.title
                        ToolTip.delay: 450
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

                StyledRect {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: tab.active ? Math.min(46, tab.width * 0.6) : 0
                    height: 3
                    radius: 1.5
                    color: Colours.palette.m3primary

                    Behavior on width {
                        Anim {}
                    }
                }
            }
        }
    }

    function syncPosition(): void {
        const index = root.tabsModel.findIndex(item => item.id === root.activeId && (root.viewingAgent ? !item.home : item.home));
        if (index >= 0)
            Qt.callLater(() => list.positionViewAtIndex(index, ListView.Contain));
    }

    onActiveIdChanged: syncPosition()
    onViewingAgentChanged: syncPosition()
}
