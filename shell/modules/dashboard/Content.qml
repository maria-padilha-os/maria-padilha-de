pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.filedialog
import qs.services

Item {
    id: root

    required property ScreenState screenState
    required property FileDialog facePicker

    Component.onCompleted: {
        if (Extensions.list.length === 0)
            Extensions.refresh();
    }

    focus: screenState.dashboard
    activeFocusOnTab: true

    Accessible.role: Accessible.Pane
    Accessible.name: Tr.tr("Dashboard")
    Accessible.description: Tr.tr("Use Left and Right to change tabs, Escape to close")
    Accessible.focusable: true
    Accessible.focused: activeFocus

    Keys.onEscapePressed: root.screenState.dashboard = false
    Keys.onLeftPressed: root.screenState.dashboardTab = Math.max(0, root.screenState.dashboardTab - 1)
    Keys.onRightPressed: root.screenState.dashboardTab = Math.min(root.dashboardTabs.length - 1, root.screenState.dashboardTab + 1)

    Connections {
        function onDashboardChanged(): void {
            if (root.screenState.dashboard)
                Qt.callLater(() => root.forceActiveFocus());
        }

        target: root.screenState
    }

    readonly property var dashboardTabs: {
        const allTabs = [
            {
                component: dashComponent,
                iconName: "dashboard",
                text: Tr.tr("Dashboard"),
                tooltip: Tr.tr("Dashboard") + " (Super + Alt + D)",
                enabled: Config.dashboard.showDashboard
            },
            {
                component: mediaComponent,
                iconName: "queue_music",
                text: Tr.tr("Media"),
                tooltip: Tr.tr("Media") + " (Super + Alt + M)",
                enabled: Config.dashboard.showMedia
            },
            {
                component: performanceComponent,
                iconName: "speed",
                text: Tr.tr("Performance"),
                tooltip: Tr.tr("Performance") + " (Super + Alt + P)",
                enabled: Config.dashboard.showPerformance
            },
            {
                component: weatherComponent,
                iconName: "cloud",
                text: Tr.tr("Weather"),
                tooltip: Tr.tr("Weather") + " (Super + Alt + W)",
                enabled: Config.dashboard.showWeather
            }
        ];
        const extensionTabs = Extensions.tabs.map(ext => ({
            component: extensionTabComponent,
            iconName: ext.icon,
            text: ext.name,
            tooltip: ext.name + (ext.shortcut.length > 0 ? ` (${ext.shortcut})` : ""),
            enabled: true,
            extension: ext
        }));
        return allTabs.filter(tab => tab.enabled).concat(extensionTabs);
    }

    readonly property real nonAnimWidth: Math.max(view.implicitWidth, tabs.minimumWidth) + viewWrapper.anchors.margins * 2
    readonly property real nonAnimHeight: tabs.implicitHeight + tabs.anchors.topMargin + view.implicitHeight + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    Tabs {
        id: tabs

        // The tab strip keeps its minimum width; only the tab content below
        // follows the extension's own width. A narrow Translator tab therefore
        // does not squeeze the tab buttons into a different size.
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: CUtils.clamp(anchors.margins - Config.border.thickness, 0, anchors.margins)
        anchors.margins: Tokens.padding.large
        width: Math.min(parent.width - anchors.margins * 2, minimumWidth)

        nonAnimWidth: width
        screenState: root.screenState
        tabs: root.dashboardTabs
    }

    ClippingRectangle {
        id: viewWrapper

        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.large

        radius: Tokens.rounding.large
        color: "transparent"

        Flickable {
            id: view

            readonly property int currentIndex: root.screenState.dashboardTab
            readonly property Item currentItem: {
                repeater.count; // Trigger update on count change
                return repeater.itemAt(currentIndex);
            }

            anchors.fill: parent

            flickableDirection: Flickable.HorizontalFlick

            readonly property bool extensionSelected: currentItem?.modelData?.extension !== undefined

            // Every pane owns its size. Extensions can therefore be wider or
            // taller than their neighbours and the panel eases between them
            // instead of forcing every tab into the last built-in size.
            implicitWidth: currentItem?.implicitWidth ?? 0
            implicitHeight: currentItem?.implicitHeight ?? 0

            contentX: currentItem?.x ?? 0
            contentWidth: row.implicitWidth
            contentHeight: row.implicitHeight

            onContentXChanged: {
                if (!moving || !currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 2)
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, tabs.count - 1);
                else if (x < -currentItem.implicitWidth / 2)
                    root.screenState.dashboardTab = Math.max(root.screenState.dashboardTab - 1, 0);
            }

            onDragEnded: {
                if (!currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 10)
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, tabs.count - 1);
                else if (x < -currentItem.implicitWidth / 10)
                    root.screenState.dashboardTab = Math.max(root.screenState.dashboardTab - 1, 0);
                else
                    contentX = Qt.binding(() => currentItem?.x ?? 0);
            }

            RowLayout {
                id: row

                Repeater {
                    id: repeater

                    model: ScriptModel {
                        values: root.dashboardTabs
                    }

                    delegate: Loader {
                        id: paneLoader

                        required property int index
                        required property var modelData

                        Layout.alignment: Qt.AlignTop

                        sourceComponent: modelData.component

                        onLoaded: {
                            if (modelData.extension) {
                                item.extension = modelData.extension;
                                item.panelWidth = 0;
                                item.panelHeight = 0;
                                item.active = Qt.binding(() => index === view.currentIndex);
                            }
                        }

                        Component.onCompleted: active = Qt.binding(() => {
                            if (index === view.currentIndex)
                                return true;
                            const vx = Math.floor(view.visibleArea.xPosition * view.contentWidth);
                            const vex = Math.floor(vx + view.visibleArea.widthRatio * view.contentWidth);
                            return (vx >= x && vx <= x + implicitWidth) || (vex >= x && vex <= x + implicitWidth);
                        })
                    }
                }
            }

            Component {
                id: dashComponent

                Dash {
                    screenState: root.screenState
                    facePicker: root.facePicker
                }
            }

            Component {
                id: mediaComponent

                Media {
                    screenState: root.screenState
                }
            }

            Component {
                id: performanceComponent

                Performance {}
            }

            Component {
                id: weatherComponent

                WeatherTab {}
            }

            Component {
                id: extensionTabComponent

                ExtensionTab {}
            }

            Behavior on contentX {
                Anim {}
            }
        }
    }

    Behavior on implicitWidth {
        Anim {}
    }

    Behavior on implicitHeight {
        Anim {}
    }
}
