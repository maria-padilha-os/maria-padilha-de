pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property var extension

    readonly property var ext: extension || ({})
    readonly property var errors: ext.errors ?? []
    readonly property var warnings: ext.warnings ?? []
    readonly property bool hasErrors: errors.length > 0
    readonly property bool hasWarnings: warnings.length > 0
    readonly property bool enabled: Extensions.isTabEnabled(ext.id ?? "")
    readonly property bool blocked: ext.canEnable !== true && !enabled

    signal toggleRequested(bool enabled)

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + Tokens.padding.largeIncreased * 2

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    border.width: hasErrors || hasWarnings ? 1 : 0
    border.color: hasErrors ? Colours.palette.m3error : Colours.palette.m3outlineVariant
    clip: true

    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        StyledRect {
            Layout.alignment: Qt.AlignTop
            implicitWidth: Tokens.font.icon.large.pointSize + Tokens.padding.large * 2
            implicitHeight: implicitWidth

            radius: Tokens.rounding.large
            color: root.hasErrors ? Colours.palette.m3errorContainer : Colours.palette.m3secondaryContainer

            MaterialIcon {
                anchors.centerIn: parent
                text: root.ext.icon || "extension"
                color: root.hasErrors ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
                fontStyle: Tokens.font.icon.large
            }
        }

        Column {
            id: body

            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                width: body.width
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.ext.name || root.ext.id || Tr.tr("Unnamed extension")
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: (root.ext.version ?? "").length > 0
                    text: `v${root.ext.version}`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                StyledText {
                    text: root.enabled ? Tr.tr("Enabled") : root.blocked ? Tr.tr("Needs attention") : Tr.tr("Disabled")
                    color: root.enabled ? Colours.palette.m3primary : root.hasErrors ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }

                StyledSwitch {
                    Layout.alignment: Qt.AlignVCenter
                    checked: root.enabled
                    disabled: root.blocked
                    onToggled: root.toggleRequested(checked)
                }
            }

            StyledText {
                width: body.width
                visible: (root.ext.description ?? "").length > 0
                text: root.ext.description ?? ""
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: body.width
                text: {
                    const version = (root.ext.version ?? "").length > 0 ? `v${root.ext.version}` : Tr.tr("version not declared");
                    return `${Tr.tr("id")}: ${root.ext.id ?? "?"} · ${version}`;
                }
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            StyledText {
                width: body.width
                text: Extensions.describeTab(root.ext)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: body.width
                text: Extensions.describeShortcut(root.ext)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: body.width
                visible: (root.ext.requires ?? []).length > 0
                text: (root.ext.missingDependencies ?? []).length > 0 ? Tr.tr("Missing dependencies: %1").arg(root.ext.missingDependencies.join(", ")) : Tr.tr("Requires: %1").arg(root.ext.requires.join(", "))
                color: (root.ext.missingDependencies ?? []).length > 0 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: body.width
                text: Tr.tr("Permissions")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            StyledText {
                width: body.width
                visible: (root.ext.permissions ?? []).length === 0
                text: Tr.tr("No special permissions declared. Extensions still run as your user, so only enable code you trust.")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                wrapMode: Text.WordWrap
            }

            Flow {
                width: body.width
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.ext.permissions ?? []

                    delegate: StyledRect {
                        required property string modelData

                        implicitWidth: chip.implicitWidth + Tokens.padding.medium * 2
                        implicitHeight: chip.implicitHeight + Tokens.padding.extraSmall

                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHigh
                        border.width: 1
                        border.color: Colours.palette.m3outlineVariant

                        RowLayout {
                            id: chip

                            anchors.centerIn: parent
                            spacing: Tokens.spacing.extraSmall

                            MaterialIcon {
                                text: "shield"
                                color: Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.small
                            }

                            StyledText {
                                text: Extensions.permissionLabel(modelData)
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                        }
                    }
                }
            }

            StyledText {
                width: body.width
                visible: (root.ext.permissions ?? []).length > 0
                text: root.ext.permissions.map(permission => Extensions.permissionDescription(permission)).join(" ")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                wrapMode: Text.WordWrap
            }

            Column {
                id: issues

                width: body.width
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.errors

                    delegate: RowLayout {
                        required property string modelData

                        width: issues.width
                        spacing: Tokens.spacing.extraSmall

                        MaterialIcon {
                            Layout.alignment: Qt.AlignTop
                            text: "error"
                            color: Colours.palette.m3error
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData
                            color: Colours.palette.m3error
                            font: Tokens.font.label.small
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Repeater {
                    model: root.warnings

                    delegate: RowLayout {
                        required property string modelData

                        width: issues.width
                        spacing: Tokens.spacing.extraSmall

                        MaterialIcon {
                            Layout.alignment: Qt.AlignTop
                            text: "warning"
                            color: Colours.palette.m3tertiary
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData
                            color: Colours.palette.m3tertiary
                            font: Tokens.font.label.small
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
