import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar as Bar
import qs.modules.assistant as AssistantPanel
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.notifications as Notifications
import qs.modules.osd as Osd
import qs.modules.session as Session
import qs.modules.sidebar as Sidebar
import qs.modules.utilities as Utilities
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities.toasts as Toasts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property Bar.BarWrapper bar
    required property real borderThickness

    readonly property alias osd: osd
    readonly property alias osdWrapper: osdWrapper
    readonly property alias notifications: notifications
    readonly property alias session: session
    readonly property alias sessionWrapper: sessionWrapper
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias popouts: popoutsWrapper.content
    readonly property alias popoutsWrapper: popoutsWrapper
    readonly property alias utilities: utilities
    readonly property alias toasts: toasts
    readonly property alias sidebar: sidebar
    readonly property alias assistant: assistant
    // Exactly one of the right drawers can be visible at a time.
    readonly property Item rightDrawer: assistant.visible ? assistant : sidebar

    anchors.fill: parent
    anchors.margins: borderThickness
    anchors.leftMargin: bar.implicitWidth

    Item {
        id: osdWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: root.rightDrawer.width * (1 - root.rightDrawer.offsetScale) + session.width * (1 - session.offsetScale)
        clip: sidebar.visible || session.visible

        implicitWidth: osd.implicitWidth * (1 - osd.offsetScale)
        implicitHeight: osd.implicitHeight

        Osd.Wrapper {
            id: osd

            screen: root.screen
            screenState: root.screenState
            sidebarOrSessionVisible: sidebar.visible || session.visible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Notifications.Wrapper {
        id: notifications

        screenState: root.screenState
        sidebarPanel: sidebar
        assistantPanel: assistant
        osdPanel: osdWrapper
        sessionPanel: sessionWrapper
        utilitiesPanel: utilities

        anchors.top: parent.top
        anchors.right: parent.right
    }

    Item {
        id: sessionWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: root.rightDrawer.width * (1 - root.rightDrawer.offsetScale)
        clip: root.rightDrawer.visible

        implicitWidth: session.implicitWidth * (1 - session.offsetScale)
        implicitHeight: session.implicitHeight

        Session.Wrapper {
            id: session

            screenState: root.screenState
            sidebarVisible: sidebar.visible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Launcher.Wrapper {
        id: launcher

        screen: root.screen
        screenState: root.screenState
        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    Dashboard.Wrapper {
        id: dashboard

        screenState: root.screenState

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    BarPopouts.ClipWrapper {
        id: popoutsWrapper

        screen: root.screen
        borderThickness: root.borderThickness
    }

    Utilities.Wrapper {
        id: utilities

        screenState: root.screenState
        sidebar: sidebar
        popouts: popoutsWrapper.content

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    Toasts.Toasts {
        id: toasts

        anchors.bottom: root.rightDrawer.visible ? parent.bottom : utilities.top
        anchors.right: root.rightDrawer.left
        anchors.margins: Tokens.padding.medium
    }

    Sidebar.Wrapper {
        id: sidebar

        screenState: root.screenState

        anchors.top: notifications.bottom
        anchors.bottom: utilities.top
        anchors.right: parent.right
        anchors.topMargin: -notifications.anchors.topMargin
    }

    AssistantPanel.Wrapper {
        id: assistant

        screenState: root.screenState

        anchors.top: notifications.bottom
        anchors.bottom: utilities.top
        anchors.right: parent.right
        anchors.topMargin: -notifications.anchors.topMargin
    }
}
