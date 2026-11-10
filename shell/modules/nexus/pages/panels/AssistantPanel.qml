pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.I18n
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Assistant")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            text: Tr.trCtx("Enabled", "toggle label")
            subtext: Tr.tr("Show the assistant drawer")
            checked: AssistantSettings.enabled
            onToggled: AssistantSettings.enabled = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Bar indicator")
            subtext: Tr.tr("Show the assistant toggle in the bar")
            checked: AssistantSettings.showIndicator
            onToggled: AssistantSettings.showIndicator = checked
        }

        SectionHeader {
            text: Tr.tr("Status")
        }

        InfoRow {
            icon: "hub"
            label: Tr.tr("Provider")
            subtext: Tr.tr("Configured in ~/.config/padilha/ai.lua")
            value: Assistant.configured ? Assistant.modelLabel : Tr.tr("Not configured")
        }

        InfoRow {
            icon: "folder"
            label: Tr.tr("Access")
            subtext: Tr.tr("Managed by padilha-ai")
            value: Assistant.rootsLabel
        }
    }
}
