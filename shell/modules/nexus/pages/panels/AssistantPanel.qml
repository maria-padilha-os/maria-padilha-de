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

    readonly property list<MenuItem> widthItems: [
        MenuItem {
            text: Tr.tr("Quarter screen")
            value: 0.25
        },
        MenuItem {
            text: Tr.tr("One third")
            value: 0.333
        },
        MenuItem {
            text: Tr.tr("Two fifths")
            value: 0.4
        },
        MenuItem {
            text: Tr.tr("Half screen")
            value: 0.5
        },
        MenuItem {
            text: Tr.tr("Three fifths")
            value: 0.6
        },
        MenuItem {
            text: Tr.tr("Two thirds")
            value: 0.667
        },
        MenuItem {
            text: Tr.tr("Three quarters")
            value: 0.75
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
            text: Tr.tr("Bar indicator")
            subtext: Tr.tr("Show the assistant toggle in the bar")
            checked: AssistantSettings.showIndicator
            onToggled: AssistantSettings.showIndicator = checked
        }

        SelectRow {
            last: true
            label: Tr.tr("Chat width")
            subtext: Tr.tr("Share of the screen occupied by the assistant · %1%").arg(Math.round(AssistantWidth.ratio * 100))
            menuItems: root.widthItems
            active: root.widthItems.find(item => Math.abs(item.value - AssistantWidth.ratio) < 0.01) ?? root.widthItems[3]
            onSelected: item => AssistantWidth.setRatio(item.value)
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

        ToggleRow {
            text: Tr.tr("Wake word")
            subtext: Tr.tr("Listen for “Padilha” and open the Assistant with dictation")
            checked: AssistantSettings.wakeEnabled
            onToggled: AssistantSettings.wakeEnabled = checked
        }

        InfoRow {
            icon: "mic"
            label: Tr.tr("Wake status")
            subtext: Tr.tr("Local Whisper listener; no audio leaves the machine")
            value: !AssistantSettings.wakeEnabled ? Tr.tr("Disabled") : (VoiceInput.error.length > 0 ? VoiceInput.error : (VoiceInput.ready ? Tr.tr("Listening") : Tr.tr("Starting…")))
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
