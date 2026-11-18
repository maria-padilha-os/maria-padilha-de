import QtQuick

Item {
    property var captureSource
    property bool live: false
    property bool hasContent: false
    component Size: QtObject {
        property real width: 0
        property real height: 0
    }
    property Size constraintSize: Size {}
}
