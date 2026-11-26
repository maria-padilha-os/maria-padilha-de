pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.I18n
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Assistant")
    isSubPage: true

    readonly property list<MenuItem> voiceItems: [
        MenuItem {
            text: Tr.tr("Maria · Dora")
            value: "pf_dora"
        },
    ]

    Component.onCompleted: {
        Assistant.start();
        Voice.refresh();
    }

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
            text: Tr.tr("Voice")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Spoken replies")
            subtext: Tr.tr("Read completed assistant answers aloud")
            checked: AssistantSettings.speakReplies
            onToggled: AssistantSettings.speakReplies = checked
        }

        SelectRow {
            label: Tr.tr("Voice")
            subtext: Voice.available ? Tr.tr("Kokoro local speech") : Tr.tr("Run padilha-voice setup to install the local voice")
            menuItems: root.voiceItems
            active: root.voiceItems.find(item => item.value === Voice.voice) ?? root.voiceItems[0]
            onSelected: item => Voice.setVoice(item.value)
        }

        SliderRow {
            last: true
            icon: "speed"
            label: Tr.tr("Speed")
            subtext: Tr.tr("Lower is slower and warmer")
            valueLabel: "x" + Voice.speed.toFixed(2)
            value: Math.max(0, Math.min(1, (Voice.speed - 0.65) / 0.5))
            onMoved: v => Voice.setSpeed(0.65 + v * 0.5)
        }

        SectionHeader {
            text: Tr.tr("Agent")
        }

        InfoRow {
            icon: "history"
            label: Tr.tr("Current session")
            subtext: Tr.tr("Select another session from the widget history button")
            value: Assistant.sessionLabel
        }

        InfoRow {
            icon: "shield"
            label: Tr.tr("Permission")
            subtext: Tr.tr("Widget sessions run with approvals off")
            value: Tr.tr("High · danger-full-access")
        }

        SectionHeader {
            text: Tr.tr("Status")
        }

        InfoRow {
            icon: "hub"
            label: Tr.tr("Provider")
            subtext: Tr.tr("DeepSeek Harness SDK")
            value: Assistant.configured ? Assistant.modelLabel : Tr.tr("Not configured")
        }

        InfoRow {
            icon: "folder"
            label: Tr.tr("Access")
            subtext: Tr.tr("Local DSH session history")
            value: Tr.trN("%n session", "%n sessions", Assistant.sessions.length)
        }
    }
}
