pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

/**
 * Display controls: the monitor's brightness and the night-light daemon.
 * One popout for the two settings that belong to the screen rather than to
 * an application.
 */
Item {
    id: root

    required property ShellScreen screen

    readonly property var monitor: Brightness.getMonitorForScreen(screen)

    property bool nightLightOn: false
    property bool nightLightBusy: false

    implicitWidth: Tokens.sizes.bar.audioWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    function setNightLight(on: bool): void {
        nightLightOn = on;
        nightLightBusy = true;
        toggleProc.command = ["sh", "-c", `exec "${Paths.home}/.config/hypr/utils/nightlight.sh" ${on ? "on" : "off"}`];
        toggleProc.running = true;
    }

    Component.onCompleted: statusProc.running = true

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.medium

        StyledText {
            text: Tr.tr("Display")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "brightness_6"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Brightness")
                    font: Tokens.font.body.small
                }

                StyledText {
                    text: `${Math.round((root.monitor?.brightness ?? 0) * 100)}%`
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }

            StyledSlider {
                Layout.fillWidth: true
                implicitHeight: Tokens.padding.medium * 3
                enabled: root.monitor !== null
                value: root.monitor?.brightness ?? 0
                onInteraction: value => root.monitor?.setBrightness(value)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "bedtime"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Night light")
                font: Tokens.font.body.small
            }

            StyledSwitch {
                checked: root.nightLightOn
                disabled: root.nightLightBusy
                onToggled: root.setNightLight(checked)
            }
        }
    }

    Process {
        id: statusProc

        command: ["sh", "-c", `exec "${Paths.home}/.config/hypr/utils/nightlight.sh" status`]

        stdout: StdioCollector {
            onStreamFinished: root.nightLightOn = text.trim() === "on"
        }
    }

    Process {
        id: toggleProc

        onExited: {
            root.nightLightBusy = false;
            statusProc.running = true;
        }
    }
}
