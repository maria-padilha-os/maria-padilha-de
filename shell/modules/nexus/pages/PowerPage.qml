pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: root.battery?.isLaptopBattery ?? false

    readonly property list<MenuItem> profileItems: [
        MenuItem {
            text: Tr.trCtx("Power saver", "power profile")
            value: PowerProfile.PowerSaver
        },
        MenuItem {
            text: Tr.trCtx("Balanced", "power profile")
            value: PowerProfile.Balanced
        },
        MenuItem {
            text: Tr.trCtx("Performance", "power profile")
            value: PowerProfile.Performance
        }
    ]

    function formatSeconds(s: int): string {
        if (s <= 0)
            return "";
        const hr = Math.floor(s / 3600);
        const min = Math.floor(s / 60) % 60;
        if (hr > 0)
            return Tr.trN("%n hour", "%n hours", hr) + (min > 0 ? " " + Tr.trN("%n min", "%n mins", min) : "");
        return Tr.trN("%n min", "%n mins", min);
    }

    function batteryState(): string {
        const dev = root.battery;
        if (!dev || !dev.isLaptopBattery)
            return Tr.tr("No battery detected");
        if (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge)
            return Tr.tr("Charging");
        if (dev.state === UPowerDeviceState.FullyCharged)
            return Tr.tr("Fully charged");
        if (dev.state === UPowerDeviceState.Discharging) {
            const time = root.formatSeconds(dev.timeToEmpty);
            return time.length > 0 ? Tr.tr("Discharging · %1 remaining").arg(time) : Tr.tr("Discharging");
        }
        return Tr.tr("Not charging");
    }

    title: Tr.tr("Power")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Battery")
        }

        InfoRow {
            icon: root.hasBattery ? Icons.getBatteryIcon(root.battery.percentage, [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged].includes(root.battery.state)) : "battery_unknown"
            label: Tr.tr("Battery")
            value: root.hasBattery ? Tr.trCtx("%1%", "battery percentage").arg(Math.round(root.battery.percentage * 100)) : Tr.tr("No battery")
            subtext: root.batteryState()
        }

        SectionHeader {
            text: Tr.tr("Power profile")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("Profile")
            subtext: Tr.tr("Balance performance and battery life")
            menuItems: root.profileItems
            active: root.profileItems.find(i => i.value === PowerProfiles.profile)
            onSelected: item => PowerProfiles.profile = item.value
        }

        SectionHeader {
            text: Tr.tr("Screen & idle")
        }

        ToggleRow {
            first: true
            text: Tr.trCtx("Keep awake", "idle inhibitor")
            subtext: Tr.tr("Prevent the screen from turning off")
            checked: IdleInhibitor.enabled
            onToggled: IdleInhibitor.enabled = checked
        }

        InfoRow {
            icon: "timer"
            label: Tr.tr("Screen off")
            subtext: Tr.tr("Managed by hypridle")
            value: Tr.tr("After 5 minutes")
        }

        SectionHeader {
            text: Tr.tr("Lid & sleep")
        }

        InfoRow {
            icon: "laptop"
            label: Tr.tr("Lid close")
            subtext: Tr.tr("Suspend and hibernate are disabled on this laptop")
            value: Tr.tr("Lock only")
        }
    }
}
