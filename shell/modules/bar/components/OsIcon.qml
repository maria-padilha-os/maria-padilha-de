import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    implicitWidth: Math.round(Tokens.font.body.large.pointSize * 1.2)
    implicitHeight: Math.round(Tokens.font.body.large.pointSize * 1.2)

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: Tr.tr("Open launcher")
    Accessible.description: Tr.tr("Open or close the application launcher")
    Accessible.focusable: true
    Accessible.focused: activeFocus
    Accessible.onPressAction: root.openLauncher()

    function openLauncher(): void {
        const screenState = ShellState.forActive();
        if (screenState)
            screenState.launcher = !screenState.launcher;
    }

    Keys.onReturnPressed: root.openLauncher()
    Keys.onEnterPressed: root.openLauncher()
    Keys.onSpacePressed: root.openLauncher()

    FocusRing {
        target: root
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.openLauncher();
        }
    }

    Loader {
        asynchronous: true
        anchors.centerIn: parent
        sourceComponent: SysInfo.isDefaultLogo ? caelestiaLogo : distroIcon
    }

    Component {
        id: caelestiaLogo

        Logo {
            implicitWidth: Math.round(Tokens.font.body.large.pointSize * 1.6)
            implicitHeight: Math.round(Tokens.font.body.large.pointSize * 1.6)
        }
    }

    Component {
        id: distroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: Math.round(Tokens.font.body.large.pointSize * 1.2)
            colour: Colours.palette.m3primary
        }
    }
}
