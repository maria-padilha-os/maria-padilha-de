pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.utils
import qs.services

Item {
    id: root

    required property color colour

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    ColumnLayout {
        id: layout

        spacing: Tokens.spacing.medium / 2

        // Bluetooth icon
        MaterialIcon {
            animate: true
            text: {
                if (!Bluetooth.defaultAdapter?.enabled) // qmllint disable unresolved-type
                    return "bluetooth_disabled";
                if (Bluetooth.devices.values.some(d => d.connected)) // qmllint disable unresolved-type
                    return "bluetooth_connected";
                return "bluetooth";
            }
            color: root.colour

            Accessible.name: !Bluetooth.defaultAdapter?.enabled ? Tr.tr("Bluetooth disabled") : Bluetooth.devices.values.some(d => d.connected) ? Tr.tr("Bluetooth connected") : Tr.tr("Bluetooth enabled")
            Accessible.role: Accessible.StaticText
        }

        // Connected bluetooth devices
        Repeater {
            model: ScriptModel {
                values: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected) // qmllint disable unresolved-type
            }

            MaterialIcon {
                id: device

                required property BluetoothDevice modelData

                animate: true
                text: Icons.getBluetoothIcon(modelData?.icon)
                color: root.colour
                fill: 1

                Accessible.name: modelData?.name ?? Tr.tr("Bluetooth device")
                Accessible.role: Accessible.StaticText

                SequentialAnimation on opacity {
                    running: device.modelData?.state !== BluetoothDeviceState.Connected && !Accessibility.reducedMotion // qmllint disable unresolved-type
                    alwaysRunToEnd: true
                    loops: Animation.Infinite

                    Anim {
                        from: 1
                        to: 0
                        duration: Accessibility.motion(Tokens.anim.durations.large)
                        easing: Tokens.anim.standardAccel
                    }
                    Anim {
                        from: 0
                        to: 1
                        duration: Accessibility.motion(Tokens.anim.durations.large)
                        easing: Tokens.anim.standardDecel
                    }
                }
            }
        }
    }
}
