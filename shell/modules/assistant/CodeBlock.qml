import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import "Highlight.js" as Highlight

ColumnLayout {
    id: root

    property string code: ""
    property string language: ""
    property bool streaming: false
    property bool allowPrivileged: false
    property string runOutput: ""
    property string runStatus: ""
    property int runCode: -1

    readonly property bool privileged: allowPrivileged && ["root", "sudo", "privileged", "sh-root"].indexOf(language.toLowerCase()) !== -1
    readonly property var highlightPalette: ({
            text: Colours.palette.m3onSurface,
            keyword: Colours.palette.m3primary,
            string: Colours.palette.m3tertiary,
            number: Colours.palette.m3secondary,
            comment: Colours.palette.m3onSurfaceVariant,
            function: Colours.palette.m3primary,
            type: Colours.palette.m3secondary
        })

    signal copyRequested(string text)

    spacing: 0

    function appendOutput(line: string): void {
        root.runOutput = (root.runOutput + line + "\n").slice(-16000);
    }

    function openConfirm(): void {
        if (!root.privileged || root.code.trim().length === 0 || root.streaming || runner.running)
            return;
        confirmPopup.open();
    }

    function runRoot(): void {
        confirmPopup.close();
        root.runOutput = "";
        root.runCode = -1;
        root.runStatus = Tr.tr("Waiting for authentication…");
        runner.command = ["pkexec", "/bin/sh", "-c", "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; " + root.code];
        runner.running = true;
    }

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.small
        color: Colours.tPalette.m3surfaceContainerHigh
        border.width: root.privileged ? 1 : 0
        border.color: Colours.palette.m3error

        ColumnLayout {
            id: inner

            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: root.privileged ? "ROOT" : (root.language.length > 0 ? root.language : "code")
                    color: root.privileged ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.builders.small.scale(0.9).build()
                }

                Item {
                    Layout.fillWidth: true
                }

                IconButton {
                    visible: root.privileged
                    icon: "play_arrow"
                    type: IconButton.Filled
                    inactiveColour: Colours.palette.m3error
                    inactiveOnColour: Colours.palette.m3onError
                    accessibleName: Tr.tr("Run as root")
                    enabled: !root.streaming && !runner.running && root.code.trim().length > 0
                    onClicked: root.openConfirm()
                }

                IconButton {
                    type: IconButton.Text
                    implicitWidth: 22
                    implicitHeight: 22
                    padding: 0
                    font: Tokens.font.icon.builders.small.build()
                    icon: "content_copy"
                    accessibleName: Tr.tr("Copy code")
                    onClicked: root.copyRequested(root.code)
                }
            }

            TextEdit {
                id: codeEdit

                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight
                readOnly: true
                selectByMouse: true
                persistentSelection: true
                textFormat: TextEdit.RichText
                text: Highlight.highlight(root.code, root.language, root.streaming, root.highlightPalette)
                wrapMode: TextEdit.Wrap
                color: Colours.palette.m3onSurface
                selectionColor: Colours.palette.m3primary
                selectedTextColor: Colours.palette.m3onPrimary

                font: Tokens.font.mono.builders.small.scale(0.92).build()
            }
        }
    }

    StyledRect {
        Layout.fillWidth: true
        visible: root.runStatus.length > 0 || root.runOutput.length > 0
        implicitHeight: outputColumn.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.small
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            id: outputColumn

            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.runStatus
                    color: root.runCode === 0 ? Colours.palette.m3primary : Colours.palette.m3error
                    font: Tokens.font.label.builders.small.scale(0.85).build()
                    elide: Text.ElideRight
                }

                IconButton {
                    type: IconButton.Text
                    visible: root.runOutput.length > 0
                    implicitWidth: 22
                    implicitHeight: 22
                    padding: 0
                    font: Tokens.font.icon.builders.small.build()
                    icon: "content_copy"
                    accessibleName: Tr.tr("Copy output")
                    onClicked: root.copyRequested(root.runOutput)
                }
            }

            TextEdit {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 220)
                visible: root.runOutput.length > 0
                readOnly: true
                selectByMouse: true
                textFormat: TextEdit.PlainText
                text: root.runOutput
                wrapMode: TextEdit.Wrap
                clip: true
                color: Colours.palette.m3onSurface
                selectionColor: Colours.palette.m3primary
                selectedTextColor: Colours.palette.m3onPrimary
                font: Tokens.font.mono.builders.small.scale(0.9).build()
            }
        }
    }

    Popup {
        id: confirmPopup

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(560, parent ? parent.width - 48 : 560)
        padding: Tokens.padding.medium
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: StyledRect {
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainerHigh
        }

        contentItem: ColumnLayout {
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Run as root?")
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.small.scale(0.95).build()
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("This command runs with administrator privileges. Review it carefully. The password is requested by polkit and is never stored by Maria Padilha.")
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.Wrap
                font: Tokens.font.label.builders.small.scale(0.86).build()
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: Math.min(preview.contentHeight, 180) + Tokens.padding.small * 2
                radius: Tokens.rounding.small
                color: Colours.tPalette.m3surfaceContainer

                TextEdit {
                    id: preview

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    readOnly: true
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    text: root.code
                    wrapMode: TextEdit.Wrap
                    clip: true
                    color: Colours.palette.m3onSurface
                    selectionColor: Colours.palette.m3primary
                    selectedTextColor: Colours.palette.m3onPrimary
                    font: Tokens.font.mono.builders.small.scale(0.9).build()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Item {
                    Layout.fillWidth: true
                }

                IconTextButton {
                    icon: "close"
                    text: Tr.tr("Cancel")
                    onClicked: confirmPopup.close()
                }

                IconTextButton {
                    icon: "lock_open"
                    text: Tr.tr("Run as root")
                    onClicked: root.runRoot()
                }
            }
        }
    }

    Process {
        id: runner

        running: false

        stdout: SplitParser {
            onRead: line => root.appendOutput(line)
        }

        stderr: SplitParser {
            onRead: line => root.appendOutput(line)
        }

        onRunningChanged: {
            if (running)
                root.runStatus = Tr.tr("Running as root…");
        }

        onExited: code => {
            root.runCode = code;
            if (code === 0)
                root.runStatus = Tr.tr("Finished · exit 0");
            else if (code === 126)
                root.runStatus = Tr.tr("Authentication cancelled");
            else if (code === 127)
                root.runStatus = Tr.tr("Not authorized");
            else
                root.runStatus = Tr.tr("Failed · exit %1").arg(code);
        }
    }
}
