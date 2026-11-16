import QtQuick
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services

// A small, theme-owned artwork surface for the media widgets. The image is
// always drawn over a palette container: a bright, missing or malformed cover
// can never turn the surrounding text into an unreadable surface.
StyledClippingRect {
    id: root

    property var player

    readonly property string artUrl: Players.getArtUrl(player)
    readonly property int imageStatus: image.status

    implicitWidth: Tokens.sizes.bar.innerWidth * 2
    implicitHeight: implicitWidth
    radius: Tokens.rounding.medium
    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)

    FadeImage {
        id: image

        anchors.fill: parent
        source: root.artUrl
        visible: status !== Image.Null && status !== Image.Error
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: root.imageStatus === Image.Error ? "broken_image" : "music_note"
        color: Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.builders.medium.build()
        opacity: root.imageStatus === Image.Ready ? 0 : 1
        animate: true

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
