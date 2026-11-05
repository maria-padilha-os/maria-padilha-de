import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(root.nState.screen)
    readonly property var hyprMonitor: Hypr.monitorFor(root.nState.screen)

    property bool nightLightOn: false
    property bool nightLightBusy: false

    title: Tr.tr("Display")

    function setNightLight(on: bool): void {
        nightLightOn = on;
        nightLightBusy = true;
        toggleProc.command = ["sh", "-c", `exec "${Paths.home}/.config/hypr/utils/nightlight.sh" ${on ? "on" : "off"}`];
        toggleProc.running = true;
    }

    Component.onCompleted: statusProc.running = true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Brightness")
        }

        SliderRow {
            first: true
            last: true
            icon: "brightness_6"
            label: Tr.tr("Brightness")
            valueLabel: `${Math.round(value * 100)}%`
            value: root.brightnessMonitor?.brightness ?? 0
            enabled: root.brightnessMonitor !== null
            onMoved: value => root.brightnessMonitor?.setBrightness(value)
        }

        SectionHeader {
            text: Tr.tr("Night light")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Night light")
            subtext: Tr.tr("Warm tint after sunset")
            checked: root.nightLightOn
            disabled: root.nightLightBusy
            onToggled: root.setNightLight(checked)
        }

        SectionHeader {
            text: Tr.tr("Monitor")
        }

        InfoRow {
            first: true
            label: Tr.tr("Output")
            value: root.hyprMonitor?.name ?? "—"
        }

        InfoRow {
            label: Tr.tr("Resolution")
            value: root.hyprMonitor ? `${root.hyprMonitor.width}×${root.hyprMonitor.height}` : "—"
        }

        InfoRow {
            label: Tr.tr("Refresh rate")
            value: root.hyprMonitor ? `${Math.round(root.hyprMonitor.refreshRate ?? 0)} Hz` : "—"
        }

        InfoRow {
            last: true
            label: Tr.tr("Scale")
            value: root.hyprMonitor ? `${root.hyprMonitor.scale ?? 1}` : "—"
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
