pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus

/**
 * GNOME-style quick settings: a toggle grid, brightness/volume sliders,
 * drill-down rows into the detailed network/audio popouts and a session
 * footer. Opened from the bar status-icon cluster.
 */
Item {
    id: root

    required property PopoutState popouts
    required property ShellScreen screen

    readonly property var monitor: Brightness.getMonitorForScreen(screen)

    property bool nightLightOn: false
    property bool nightLightBusy: false

    implicitWidth: 360
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    function runCommand(command: list<string>): void {
        if (!SessionManager.exec(command))
            Quickshell.execDetached(command);
    }

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
        spacing: Tokens.spacing.small

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            columns: 3
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            QuickToggle {
                icon: "wifi"
                label: Tr.tr("Wi-Fi")
                checked: Nmcli.wifiEnabled
                onClicked: Nmcli.toggleWifi()
            }

            QuickToggle {
                icon: "bluetooth"
                label: Tr.tr("Bluetooth")
                checked: Bluetooth.defaultAdapter?.enabled ?? false // qmllint disable unresolved-type
                onClicked: {
                    const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
                    if (adapter)
                        adapter.enabled = !adapter.enabled;
                }
            }

            QuickToggle {
                icon: "bedtime"
                label: Tr.tr("Night light")
                checked: root.nightLightOn
                enabled: !root.nightLightBusy
                onClicked: root.setNightLight(!root.nightLightOn)
            }

            QuickToggle {
                icon: "notifications_off"
                label: Tr.tr("DND")
                checked: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }

            QuickToggle {
                icon: "gamepad"
                label: Tr.tr("Game mode")
                checked: GameMode.enabled
                onClicked: GameMode.enabled = !GameMode.enabled
            }

            QuickToggle {
                icon: "coffee"
                label: Tr.tr("Caffeine")
                checked: IdleInhibitor.enabled
                onClicked: IdleInhibitor.enabled = !IdleInhibitor.enabled
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.medium
            icon: "brightness_6"
            label: Tr.tr("Brightness")
            value: root.monitor?.brightness ?? 0
            valueText: `${Math.round((root.monitor?.brightness ?? 0) * 100)}%`
            onMoved: v => root.monitor?.setBrightness(v)
        }

        SliderRow {
            icon: Audio.muted ? "volume_off" : "volume_up"
            label: Tr.tr("Volume")
            value: Audio.volume
            valueText: Audio.muted ? Tr.tr("Muted") : `${Math.round(Audio.volume * 100)}%`
            leadingClickable: true
            onLeadingClicked: {
                const audio = Audio.sink?.audio;
                if (audio)
                    audio.muted = !audio.muted;
            }
            onMoved: v => Audio.setVolume(v)
        }

        LinkRow {
            icon: Nmcli.activeEthernet ? "cable" : Nmcli.active ? "wifi" : "wifi_off"
            text: Tr.tr("Wi-Fi networks")
            detail: Nmcli.activeEthernet ? Tr.tr("Ethernet") : (Nmcli.active?.ssid ?? Tr.tr("Disconnected"))
            onClicked: root.popouts.currentName = "network"
        }

        LinkRow {
            icon: Bluetooth.defaultAdapter?.enabled ? "bluetooth" : "bluetooth_disabled"
            text: Tr.tr("Bluetooth")
            detail: {
                const connected = (Bluetooth.devices.values ?? []).filter(d => d.connected);
                if (connected.length > 0)
                    return connected.map(d => d.name).join(", ");
                return Bluetooth.defaultAdapter?.enabled ? Tr.tr("On") : Tr.tr("Off");
            }
            onClicked: root.popouts.currentName = "bluetooth"
        }

        LinkRow {
            icon: "speaker"
            text: Tr.tr("Output")
            detail: Audio.sink?.description ?? ""
            onClicked: root.popouts.currentName = "audio"
        }

        LinkRow {
            visible: UPower.displayDevice.isLaptopBattery
            icon: Icons.getBatteryIcon(UPower.displayDevice.percentage, [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state))
            text: Tr.tr("Battery")
            detail: `${Math.round(UPower.displayDevice.percentage * 100)}%`
            onClicked: root.popouts.currentName = "battery"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            implicitHeight: 1
            color: Colours.palette.m3onSurface
            opacity: 0.12
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            FooterButton {
                icon: "settings"
                onClicked: {
                    root.popouts.hasCurrent = false;
                    WindowFactory.create();
                }
            }

            FooterButton {
                icon: "lock"
                onClicked: {
                    root.popouts.hasCurrent = false;
                    // Go through the shell IPC: `hyprctl dispatch global ...`
                    // no longer parses under the Lua dispatcher.
                    Quickshell.execDetached(["caelestia", "shell", "lock", "lock"]);
                }
            }

            FooterButton {
                icon: Config.session.icons.logout
                onClicked: root.runCommand(Config.session.commands.logout)
            }

            FooterButton {
                icon: Config.session.icons.reboot
                onClicked: root.runCommand(Config.session.commands.reboot)
            }

            FooterButton {
                icon: Config.session.icons.shutdown
                onClicked: root.runCommand(Config.session.commands.shutdown)
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

    component QuickToggle: StyledRect {
        id: tile

        property string icon
        property string label
        property bool checked
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: (layout.width - Tokens.spacing.small * 2) / 3
        implicitHeight: 58
        radius: Tokens.rounding.large
        color: tile.checked ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
        clip: true

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Tokens.padding.small * 2
            spacing: 1

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: tile.icon
                color: tile.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                fontStyle: Tokens.font.icon.medium
                fill: tile.checked ? 1 : 0
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width
                text: tile.label
                color: tile.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
        }

        StateLayer {
            radius: tile.radius
            onClicked: tile.clicked()
        }
    }

    component SliderRow: ColumnLayout {
        id: row

        property string icon
        property string label
        property real value
        property string valueText
        property bool leadingClickable
        signal leadingClicked()
        signal moved(real v)

        Layout.fillWidth: true
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Item {
                implicitWidth: leadingIcon.implicitWidth
                implicitHeight: leadingIcon.implicitHeight

                MaterialIcon {
                    id: leadingIcon

                    anchors.centerIn: parent
                    text: row.icon
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }

                StateLayer {
                    anchors.fill: undefined
                    anchors.centerIn: parent
                    implicitWidth: parent.implicitWidth + Tokens.padding.extraSmall * 2
                    implicitHeight: parent.implicitHeight + Tokens.padding.extraSmall * 2
                    radius: Tokens.rounding.full
                    enabled: row.leadingClickable
                    onClicked: row.leadingClicked()
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: row.label
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
            }

            StyledText {
                text: row.valueText
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }

        StyledSlider {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.medium * 2
            value: row.value
            onInteraction: v => row.moved(v)
        }
    }

    component LinkRow: Item {
        id: link

        property string icon
        property string text
        property string detail
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: Tokens.padding.extraLarge

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.small
            anchors.rightMargin: Tokens.padding.small
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: link.icon
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                text: link.text
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.maximumWidth: 140
                text: link.detail
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            MaterialIcon {
                text: "chevron_right"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }
        }

        StateLayer {
            radius: Tokens.rounding.medium
            onClicked: link.clicked()
        }
    }

    component FooterButton: IconButton {
        Layout.fillWidth: true
        implicitHeight: 40
        isToggle: false
        inactiveColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
        inactiveOnColour: Colours.palette.m3onSurface
        radius: Tokens.rounding.medium
    }
}
