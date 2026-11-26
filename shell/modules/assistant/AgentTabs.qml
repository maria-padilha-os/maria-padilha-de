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

    visible: agents.length > 0 || viewingAgent
    implicitHeight: 40

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

            width: Math.min(190, Math.max(108, label.implicitWidth + 44))
            height: list.height
            padding: 0

            onClicked: modelData.home ? root.homeRequested() : root.agentRequested(modelData.id)

            background: StyledRect {
                radius: Tokens.rounding.small
                color: tab.active ? Colours.tPalette.m3secondaryContainer : (tab.hovered ? Colours.tPalette.m3surfaceContainerHighest : "transparent")
            }

            contentItem: RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.small
                anchors.rightMargin: Tokens.padding.small
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    text: modelData.home ? "home" : "smart_toy"
                    color: tab.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    id: label

                    Layout.fillWidth: true
                    text: modelData.title
                    color: tab.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font: Tokens.font.label.builders.small.scale(0.9).build()
                    elide: Text.ElideRight
                }

                StyledRect {
                    visible: modelData.owned
                    implicitWidth: 7
                    implicitHeight: 7
                    radius: 3.5
                    color: Colours.palette.m3primary
                }
            }
        }
    }

    onActiveIdChanged: {
        const index = root.tabsModel.findIndex(tab => tab.id === root.activeId && (root.viewingAgent ? !tab.home : tab.home));
        if (index >= 0)
            Qt.callLater(() => list.positionViewAtIndex(index, ListView.Contain));
    }
}
