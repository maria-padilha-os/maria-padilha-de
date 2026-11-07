import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services

// System overview driven by the shell's existing services. Cpu and Memory tick
// at dashboard.resourceUpdateInterval; the load average is a small /proc read
// refreshed at a deliberately slower pace.
Item {
    id: root

    property var api
    property bool active: true
    property bool compact: false

    property string load1: "—"
    property string load5: "—"
    property string load15: "—"

    readonly property var palette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color foreground: root.palette ? root.palette.m3onSurface : "transparent"
    readonly property color muted: root.palette ? root.palette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.palette ? root.palette.m3primary : "transparent"
    readonly property color secondary: root.palette ? root.palette.m3tertiary : "transparent"
    readonly property color outline: root.palette ? root.palette.m3outlineVariant : "transparent"

    readonly property real contentWidth: Math.min(Math.max(280, root.width - (root.compact ? Tokens.padding.medium : Tokens.padding.large) * 2), 640)

    // Load average changes slowly and is not exposed by a service, so read it
    // at no more than one fifth of the configured resource update rate, with a
    // five second floor to avoid needless wakeups.
    readonly property int refreshInterval: Math.max(5000, (root.api && root.api.config && root.api.config.dashboard ? Number(root.api.config.dashboard.resourceUpdateInterval) || 1000 : 1000) * 5)

    function formatPercent(value: real): string {
        const clamped = Math.max(0, Math.min(1, Number(value) || 0));
        return `${Math.round(clamped * 100)}%`;
    }

    function updateLoad(source: string): void {
        const fields = String(source ?? "").trim().split(/\s+/);
        root.load1 = fields[0] || "—";
        root.load5 = fields[1] || "—";
        root.load15 = fields[2] || "—";
    }

    ServiceRef {
        service: root.active ? Cpu : null
    }

    ServiceRef {
        service: root.active ? Memory : null
    }

    FileView {
        id: loadFile

        path: "/proc/loadavg"
        printErrors: false
        onLoaded: root.updateLoad(text())
    }

    Timer {
        interval: root.refreshInterval
        repeat: true
        running: root.active
        onTriggered: loadFile.reload()
    }

    component UsageBar: Item {
        id: bar

        property real value: 0
        property color colour: root.accent

        implicitHeight: 8

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.alpha(root.outline, 0.35)
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: parent.width * Math.max(0, Math.min(1, bar.value))
            radius: height / 2
            color: bar.colour
        }
    }

    component MetricRow: ColumnLayout {
        id: metric

        required property string label
        required property string value
        required property string detail
        required property real fraction
        property color colour: root.accent

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Text {
                Layout.fillWidth: true
                text: metric.label
                color: root.foreground
                font.pixelSize: 15
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                text: metric.value
                color: metric.colour
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }

        UsageBar {
            Layout.fillWidth: true
            value: metric.fraction
            colour: metric.colour
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: metric.detail
            color: root.muted
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.contentWidth
        spacing: root.compact ? Tokens.spacing.small : Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Text {
                Layout.fillWidth: true
                text: Tr.tr("System monitor")
                color: root.foreground
                font.pixelSize: 20
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                text: Cpu.name || Tr.tr("Live")
                color: root.muted
                font.pixelSize: 12
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }
        }

        MetricRow {
            label: Tr.tr("CPU")
            value: root.formatPercent(Cpu.percentage)
            detail: Cpu.temperature > 0 ? Tr.tr("%1°C").arg(Math.round(Cpu.temperature)) : Tr.tr("Processor")
            fraction: Cpu.percentage
            colour: root.accent
        }

        MetricRow {
            label: Tr.tr("Memory")
            value: root.formatPercent(Memory.percentage)
            detail: Units.formatKibUsage(Memory.used, Memory.total)
            fraction: Memory.percentage
            colour: root.secondary
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: Tr.tr("Load average")
                    color: root.foreground
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                Text {
                    text: Tr.tr("/proc/loadavg")
                    color: root.muted
                    font.pixelSize: 11
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: [
                        {
                            label: Tr.tr("1 min"),
                            value: root.load1
                        },
                        {
                            label: Tr.tr("5 min"),
                            value: root.load5
                        },
                        {
                            label: Tr.tr("15 min"),
                            value: root.load15
                        }
                    ]

                    delegate: ColumnLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.value
                            color: root.foreground
                            font.pixelSize: 24
                            font.family: "monospace"
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label
                            color: root.muted
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
