import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.widgets
import qs.services

// Compact media item for the vertical bar. It is deliberately only a cover and
// a progress line: the details, seek and volume controls live in the popout.
Item {
    id: root

    required property var bar

    readonly property var player: Players.active
    readonly property bool hasPlayer: !!player
    readonly property bool playing: player?.isPlaying ?? false
    readonly property real progress: Players.progress(player)
    readonly property real artSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small
    readonly property string title: Players.getTrackTitle(player, Tr.tr("Nothing playing"))
    readonly property string subtitle: Players.getTrackArtist(player, Tr.tr("No active media player"))

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: artSize + Tokens.spacing.extraSmall + Tokens.padding.extraSmall

    activeFocusOnTab: true
    Accessible.name: `${Tr.tr("Media")}: ${title} — ${subtitle}`
    Accessible.description: Tr.tr("Open or close the media controls")
    Accessible.role: Accessible.Button
    Accessible.focusable: true
    Accessible.focused: activeFocus
    Accessible.onPressAction: root.togglePopout()

    function togglePopout(): void {
        const popouts = root.bar.popouts;
        if (popouts.hasCurrent && popouts.currentName === "media") {
            popouts.hasCurrent = false;
            return;
        }
        popouts.currentName = "media";
        popouts.currentCenter = root.mapToItem(root.bar, 0, root.implicitHeight / 2).y;
        popouts.hasCurrent = true;
    }

    Keys.onReturnPressed: root.togglePopout()
    Keys.onEnterPressed: root.togglePopout()
    Keys.onSpacePressed: root.togglePopout()

    FocusRing {
        target: root
        radius: Tokens.rounding.medium
    }

    Timer {
        running: root.playing
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    MediaArtwork {
        id: artwork

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: root.artSize
        implicitHeight: root.artSize
        player: root.player
        visible: root.hasPlayer
    }

    MaterialIcon {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.artSize
        height: root.artSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "music_off"
        color: Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.builders.small.build()
        visible: !root.hasPlayer
    }

    StyledRect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        implicitHeight: 2
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainerHighest
        visible: root.hasPlayer
    }

    StyledRect {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        implicitWidth: parent.width * root.progress
        implicitHeight: 2
        radius: Tokens.rounding.full
        color: Colours.palette.m3primary
        visible: root.hasPlayer && root.progress > 0

        Behavior on implicitWidth {
            Anim {
                type: Anim.StandardLarge
            }
        }
    }

    StateLayer {
        anchors.fill: parent
        radius: Tokens.rounding.medium
        onClicked: {
            root.forceActiveFocus();
            root.togglePopout();
        }
    }
}
