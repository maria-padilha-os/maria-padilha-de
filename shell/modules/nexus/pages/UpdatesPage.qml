import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    property bool confirming: false
    property bool copiedLog: false

    readonly property var updates: Updates.updates
    readonly property var summary: Updates.summary
    readonly property var warningCodes: Updates.warnings
    readonly property bool hasUpdates: Updates.hasUpdates
    readonly property bool busy: Updates.checking || Updates.applying
    readonly property bool resultFailed: Updates.error.length > 0 || Updates.lastApplyFailed
    readonly property bool showResult: Updates.error.length > 0 || Updates.applyMessage.length > 0 || Updates.applyError.length > 0
    readonly property string resultTitle: {
        if (Updates.error.length > 0)
            return Tr.tr("Update check failed");
        if (Updates.applyOK)
            return Tr.tr("Update finished");
        if (Updates.lastApplyFailed)
            return Tr.tr("Update failed");
        return "";
    }
    readonly property string resultMessage: {
        if (Updates.error.length > 0)
            return Updates.error;
        if (Updates.applyError.length > 0)
            return Updates.applyError;
        return Updates.applyMessage;
    }

    function refresh(): void {
        root.confirming = false;
        Updates.check();
    }

    function requestApply(): void {
        if (root.busy || !root.hasUpdates)
            return;
        root.confirming = true;
    }

    function cancelApply(): void {
        root.confirming = false;
    }

    function confirmApply(): void {
        if (!root.confirming || root.busy)
            return;
        root.confirming = false;
        Updates.apply(true);
    }

    function warningText(code: string): string {
        if (code === "battery-low")
            return Tr.tr("Battery is low (%1%). Plug in the charger before applying this update.").arg(Updates.batteryPercent);
        if (code === "not-on-ac-large")
            return Tr.tr("This is a large update (%1 download) and the session is on battery. Plug in the charger before applying it.").arg(root.summary.downloadLabel ?? "unknown");
        return "";
    }

    function summaryText(): string {
        if (Updates.checking)
            return Tr.tr("Checking for updates…");
        if (Updates.error.length > 0)
            return Tr.tr("Could not check for updates");
        if (!Updates.hasChecked)
            return Tr.tr("No update check has run yet");
        if (root.updates.length === 0)
            return Tr.tr("System is up to date");

        const countText = root.updates.length === 1 ? Tr.tr("1 update available") : Tr.tr("%1 updates available").arg(root.updates.length);
        let text = Tr.tr("%1 · %2 download · %3 installed").arg(countText).arg(root.summary.downloadLabel ?? "unknown").arg(root.summary.installLabel ?? "unknown");
        if (root.summary.unknownDownload > 0 || root.summary.unknownInstall > 0)
            text += " " + Tr.tr("Some package sizes are unknown.");
        return text;
    }

    function sizeText(item: var): string {
        return Tr.tr("%1 download · %2 installed").arg(item.downloadLabel ?? "unknown").arg(item.installLabel ?? "unknown");
    }

    function copyLogPath(): void {
        if (Updates.logPath.length === 0)
            return;
        Quickshell.clipboardText = Updates.logPath;
        root.copiedLog = true;
        copyTimer.restart();
    }

    title: Tr.tr("Updates")

    Component.onCompleted: Updates.check()

    Keys.onEscapePressed: event => {
        if (root.confirming) {
            root.cancelApply();
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: root.summaryText()
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Tonal
                isRound: true
                accessibleName: Tr.tr("Check for updates")
                enabled: !root.busy
                onClicked: root.refresh()
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.updates.length > 0 && !Updates.checking
            text: Tr.tr("Nothing is downloaded or installed until you review the list and confirm.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.warningCodes

            delegate: StyledText {
                required property var modelData

                Layout.fillWidth: true
                text: root.warningText(modelData)
                color: Colours.palette.m3error
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }
        }

        SectionHeader {
            visible: root.updates.length > 0
            text: Tr.tr("Packages")
        }

        Repeater {
            model: root.updates

            delegate: InfoRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === root.updates.length - 1
                label: modelData.name
                subtext: root.sizeText(modelData) + (modelData.ignored ? " · " + Tr.tr("Ignored by pacman") : "")
                value: Tr.tr("%1 → %2").arg(modelData.oldVersion).arg(modelData.newVersion)
            }
        }

        SectionHeader {
            visible: root.hasUpdates
            text: Tr.tr("Apply")
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.hasUpdates && !root.confirming
            text: Tr.tr("Applying needs your confirmation. Maria Padilha never updates or reboots on its own.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        IconTextButton {
            visible: root.hasUpdates && !root.confirming
            text: Tr.tr("Review and apply")
            icon: "system_update_alt"
            type: IconTextButton.Filled
            enabled: !root.busy
            onClicked: root.requestApply()
        }

        StyledText {
            Layout.fillWidth: true
            visible: Updates.applying
            text: Tr.tr("Applying updates… Do not power off the machine. A reboot is never started automatically.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledRect {
            Layout.fillWidth: true
            visible: root.confirming
            implicitHeight: confirmation.implicitHeight + Tokens.padding.large * 2
            color: Colours.tPalette.m3surfaceContainerHigh
            radius: Tokens.rounding.large

            ColumnLayout {
                id: confirmation

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.small

                StyledText {
                    text: root.summary.count === 1 ? Tr.tr("Apply 1 update?") : Tr.tr("Apply %1 updates?").arg(root.summary.count)
                    font: Tokens.font.title.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("%1 download · %2 installed. Nothing is installed until you confirm.").arg(root.summary.downloadLabel ?? "unknown").arg(root.summary.installLabel ?? "unknown")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: root.warningCodes

                    delegate: StyledText {
                        required property var modelData

                        Layout.fillWidth: true
                        text: root.warningText(modelData)
                        color: Colours.palette.m3error
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.small

                    Item {
                        Layout.fillWidth: true
                    }

                    TextButton {
                        text: Tr.trCtx("Cancel", "button")
                        type: TextButton.Text
                        onClicked: root.cancelApply()
                    }

                    TextButton {
                        text: Tr.tr("Confirm update")
                        type: TextButton.Filled
                        onClicked: root.confirmApply()
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            visible: root.showResult
            implicitHeight: result.implicitHeight + Tokens.padding.large * 2
            color: root.resultFailed ? Qt.alpha(Colours.palette.m3error, 0.12) : Colours.tPalette.m3surfaceContainerHigh
            radius: Tokens.rounding.large

            ColumnLayout {
                id: result

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.small

                RowLayout {
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: root.resultFailed ? "error" : "check_circle"
                        color: root.resultFailed ? Colours.palette.m3error : Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.resultTitle
                        font: Tokens.font.title.small
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.resultMessage.length > 0
                    text: root.resultMessage
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Updates.logPath.length > 0
                    text: Updates.logPath
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.mono.small
                    wrapMode: Text.WrapAnywhere
                }

                IconTextButton {
                    visible: Updates.logPath.length > 0
                    text: root.copiedLog ? Tr.tr("Copied") : Tr.tr("Copy log path")
                    icon: root.copiedLog ? "check" : "content_copy"
                    type: IconTextButton.Tonal
                    onClicked: root.copyLogPath()
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.resultFailed && Updates.logTail.length > 0
                    text: Updates.logTail
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.mono.small
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }

    Item {
        id: copyTimerHost

        Timer {
            id: copyTimer

            interval: 1600
            onTriggered: root.copiedLog = false
        }
    }
}
