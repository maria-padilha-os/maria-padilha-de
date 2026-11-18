pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.widgets
import qs.services

ColumnLayout {
    id: root

    readonly property MprisPlayer player: Players.active
    readonly property list<MprisPlayer> players: Players.list
    readonly property bool hasPlayer: !!player
    readonly property bool playing: player?.isPlaying ?? false
    readonly property bool canSeek: Players.canSeek(player)
    readonly property bool canVolume: Players.canSetVolume(player)
    readonly property bool knownLength: Players.isKnownLength(player)
    readonly property real progress: Players.progress(player)

    implicitWidth: Tokens.sizes.bar.audioWidth
    spacing: Tokens.spacing.small

    focus: true
    activeFocusOnTab: true

    Component.onCompleted: Qt.callLater(() => root.forceActiveFocus())

    Keys.onPressed: event => {
        const action = Players.actionForKey(event.key, (event.modifiers & Qt.ShiftModifier) !== 0);
        if (action === "none")
            return;
        Players.perform(action);
        event.accepted = true;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Media")
            font: Tokens.font.title.small
        }

        SplitButton {
            id: selector

            visible: root.players.length > 1
            type: SplitButton.Tonal
            active: playerMenu.instances.find(m => m.modelData === root.player) ?? playerMenu.instances[0] ?? null
            menu.onItemSelected: item => Players.manualActive = (item as PlayerItem).modelData

            menuItems: playerMenu.instances
            fallbackIcon: "music_note"
            fallbackText: root.player ? Players.getIdentity(root.player) : Tr.tr("No player")
            minLeftWidth: Tokens.sizes.bar.innerWidth * 3
            label.elide: Text.ElideRight
            label.Layout.maximumWidth: Math.max(Tokens.sizes.bar.innerWidth * 2, root.width - expandBtn.implicitWidth - horizontalPadding * 2)
        }

        Variants {
            id: playerMenu

            model: root.players

            PlayerItem {}
        }
    }

    Loader {
        Layout.fillWidth: true
        active: root.hasPlayer
        visible: active
        sourceComponent: contentComp
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.medium
        Layout.bottomMargin: Tokens.spacing.small
        spacing: Tokens.spacing.small
        visible: !root.hasPlayer

        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Tokens.sizes.bar.innerWidth * 2
            implicitHeight: implicitWidth
            radius: Tokens.rounding.full
            color: Colours.palette.m3primaryContainer

            MaterialIcon {
                anchors.centerIn: parent
                text: "music_off"
                color: Colours.palette.m3onPrimaryContainer
                fontStyle: Tokens.font.icon.builders.large.scale(1.5).build()
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Tr.tr("Nothing playing")
            font: Tokens.font.title.small
            color: Colours.palette.m3onSurface
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: Tr.tr("Start playback in a media app to use these controls.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }

    Component {
        id: contentComp

        ColumnLayout {
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                MediaArtwork {
                    implicitWidth: Tokens.sizes.bar.innerWidth * 2
                    implicitHeight: implicitWidth
                    player: root.player
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: Players.getTrackTitle(root.player, Tr.tr("Unknown track"))
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                        animate: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Players.getTrackArtist(root.player, Tr.tr("Unknown artist"))
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                        animate: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Players.getTrackAlbum(root.player, Tr.tr("Unknown album"))
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                        animate: true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                TextMetrics {
                    id: timeMetrics

                    text: "00:00"
                    font: Tokens.font.label.small
                }

                StyledText {
                    Layout.preferredWidth: timeMetrics.width
                    text: Players.formatTime(root.player?.position ?? -1)
                    color: Colours.palette.m3onSurfaceVariant
                    font: timeMetrics.font
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledSlider {
                    id: seekSlider

                    Layout.fillWidth: true
                    accessibleName: Tr.tr("Seek")
                    value: root.progress
                    enabled: root.canSeek
                    interactionOnMove: false
                    onInteraction: value => {
                        const target = Players.seekTarget(root.player, value);
                        if (target >= 0 && root.player)
                            root.player.position = target;
                    }
                }

                StyledText {
                    Layout.preferredWidth: timeMetrics.width
                    text: root.knownLength ? Players.formatTime(root.player?.length ?? -1) : "--:--"
                    color: Colours.palette.m3onSurfaceVariant
                    font: timeMetrics.font
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            ButtonRow {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    type: IconButton.Tonal
                    icon: "skip_previous"
                    isRound: true
                    shapeMorph: true
                    disabled: !root.player?.canGoPrevious
                    Accessible.name: Tr.tr("Previous track")
                    onClicked: root.player?.previous()
                }

                IconButton {
                    fillWidth: true
                    icon: root.playing ? "pause" : "play_arrow"
                    isRound: true
                    shapeMorph: true
                    checked: root.playing
                    disabled: !root.player?.canTogglePlaying
                    Accessible.name: root.playing ? Tr.tr("Pause") : Tr.tr("Play")
                    onClicked: root.player?.togglePlaying()
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: "skip_next"
                    isRound: true
                    shapeMorph: true
                    disabled: !root.player?.canGoNext
                    Accessible.name: Tr.tr("Next track")
                    onClicked: root.player?.next()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall
                spacing: Tokens.spacing.small
                visible: root.canVolume

                MaterialIcon {
                    text: {
                        const volume = Players.getVolume(root.player);
                        if (volume <= 0)
                            return "volume_mute";
                        if (volume < 0.5)
                            return "volume_down";
                        return "volume_up";
                    }
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }

                StyledSlider {
                    Layout.fillWidth: true
                    accessibleName: Tr.tr("Player volume")
                    value: Players.getVolume(root.player)
                    enabled: root.canVolume
                    onInteraction: value => Players.setVolume(root.player, value)
                }

                StyledText {
                    Layout.preferredWidth: timeMetrics.width
                    text: `${Players.getVolumePercent(root.player)}%`
                    color: Colours.palette.m3onSurfaceVariant
                    font: timeMetrics.font
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    component PlayerItem: MenuItem {
        required property MprisPlayer modelData

        icon: modelData === Players.active ? "check" : ""
        text: Players.getIdentity(modelData)
        activeIcon: "animated_images"
    }
}
