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

    readonly property var dashboardTabs: {
        const allTabs = [
            {
                component: dashComponent,
                iconName: "dashboard",
                text: Tr.tr("Dashboard"),
                enabled: Config.dashboard.showDashboard
            },
            {
                component: mediaComponent,
                iconName: "queue_music",
                text: Tr.tr("Media"),
                enabled: Config.dashboard.showMedia
            },
            {
                component: performanceComponent,
                iconName: "speed",
                text: Tr.tr("Performance"),
                enabled: Config.dashboard.showPerformance
            },
            {
                component: weatherComponent,
                iconName: "cloud",
                text: Tr.tr("Weather"),
                enabled: Config.dashboard.showWeather
            }
        ];
        const extensionTabs = Extensions.tabs.map(ext => ({
            component: extensionTabComponent,
            iconName: ext.icon,
            text: ext.name,
            enabled: true,
            extension: ext
        }));
        return allTabs.filter(tab => tab.enabled).concat(extensionTabs);
    }

    readonly property real nonAnimWidth: view.implicitWidth + viewWrapper.anchors.margins * 2
    readonly property real nonAnimHeight: tabs.implicitHeight + tabs.anchors.topMargin + view.implicitHeight + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    Tabs {
        id: tabs

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: CUtils.clamp(anchors.margins - Config.border.thickness, 0, anchors.margins)
        anchors.margins: Tokens.padding.large

        nonAnimWidth: root.nonAnimWidth - anchors.margins * 2
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

            // The panel keeps the size of the largest tab instead of shrinking
            // to the selected one; otherwise a narrow extension tab squeezes
            // the whole tab bar.
            readonly property real widestTab: {
                let width = 0;
                for (let i = 0; i < repeater.count; i++)
                    width = Math.max(width, repeater.itemAt(i)?.implicitWidth ?? 0);
                return width;
            }
            readonly property real tallestTab: {
                let height = 0;
                for (let i = 0; i < repeater.count; i++)
                    height = Math.max(height, repeater.itemAt(i)?.implicitHeight ?? 0);
                return height;
            }

            implicitWidth: Math.max(currentItem?.implicitWidth ?? 0, widestTab)
            implicitHeight: Math.max(currentItem?.implicitHeight ?? 0, tallestTab)

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
                            if (modelData.extension)
                                item.extension = modelData.extension;
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
