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

            readonly property bool extensionSelected: currentItem?.modelData?.extension !== undefined

            // Remember the last built-in tab size. Extension tabs borrow it,
            // so switching to one neither shrinks nor grows the panel.
            property real stableWidth: 0
            property real stableHeight: 0

            Binding {
                target: view
                property: "stableWidth"
                value: view.currentItem?.implicitWidth ?? 0
                when: !view.extensionSelected && view.currentItem !== null
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: view
                property: "stableHeight"
                value: view.currentItem?.implicitHeight ?? 0
                when: !view.extensionSelected && view.currentItem !== null
                restoreMode: Binding.RestoreNone
            }

            implicitWidth: extensionSelected ? Math.max(currentItem?.implicitWidth ?? 0, stableWidth) : currentItem?.implicitWidth ?? 0
            implicitHeight: extensionSelected ? Math.max(currentItem?.implicitHeight ?? 0, stableHeight) : currentItem?.implicitHeight ?? 0

            Component.onCompleted: {
                for (let i = 0; i < repeater.count; i++) {
                    const loader = repeater.itemAt(i);
                    if (loader && loader.modelData?.extension === undefined) {
                        stableWidth = loader.implicitWidth;
                        stableHeight = loader.implicitHeight;
                        break;
                    }
                }
            }

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
                                item.panelWidth = Qt.binding(() => view.stableWidth);
                                item.panelHeight = Qt.binding(() => view.stableHeight);
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
