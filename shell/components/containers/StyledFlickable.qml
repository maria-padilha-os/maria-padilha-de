import QtQuick
import qs.components

Flickable {
    id: root

    property bool doneFakeFlick

    // Qt scrolls high-resolution touchpad deltas almost 1:1, which feels
    // sluggish. Scale them here and let the default handling stay untouched.
    property real wheelMultiplier: 2.5
    property real wheelStep: 60

    maximumFlickVelocity: 3000

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            if (!root.interactive)
                return;

            const pixel = event.pixelDelta;
            const angle = event.angleDelta;
            const horizontal = Math.abs(pixel.x) + Math.abs(angle.x) > Math.abs(pixel.y) + Math.abs(angle.y);
            const delta = horizontal ? (pixel.x !== 0 ? pixel.x : angle.x / 120 * root.wheelStep) : (pixel.y !== 0 ? pixel.y : angle.y / 120 * root.wheelStep);
            if (delta === 0)
                return;

            if (horizontal) {
                const maxX = Math.max(0, root.contentWidth - root.width);
                root.contentX = Math.max(0, Math.min(maxX, root.contentX - delta * root.wheelMultiplier));
            } else {
                const maxY = Math.max(0, root.contentHeight + root.topMargin + root.bottomMargin - root.height);
                root.contentY = Math.max(0, Math.min(maxY, root.contentY - delta * root.wheelMultiplier));
            }
            event.accepted = true;
        }
    }

    rebound: Transition {
        onRunningChanged: {
            if (!running && !root.doneFakeFlick) {
                root.doneFakeFlick = true;
                root.flick(1, 1);
                root.flick(-1, -1);
                Qt.callLater(() => root.cancelFlick());
            }
        }

        Anim {
            properties: "x,y"
        }
    }

    Timer {
        running: root.doneFakeFlick
        interval: 10
        onTriggered: root.doneFakeFlick = false
    }
}
