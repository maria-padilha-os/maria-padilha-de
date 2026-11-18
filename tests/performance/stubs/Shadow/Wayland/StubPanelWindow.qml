// A PanelWindow without a Wayland backend. It keeps the QML object tree and
// properties the shell binds to, but renders nothing.
import QtQuick

Item {
    id: window

    property var screen
    property var mask
    property color color: "transparent"
    property int exclusiveZone: 0
    property int exclusionMode: 0
    property int keyboardFocus: 0
    property string namespace: ""
    component Format: QtObject {
        property bool opaque: true
    }
    property Format surfaceFormat: Format {}
    property Item activeFocusItem: null
    readonly property Item contentItem: inner
    default property alias contentData: inner.data
    implicitWidth: 0
    implicitHeight: 0

    Item {
        id: inner
        anchors.fill: parent
    }
}
