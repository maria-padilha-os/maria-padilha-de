// Layer-shell regions are only masks. The benchmark does not composite them,
// so a plain object with the same geometry is enough.
import QtQml

QtObject {
    property real x: 0
    property real y: 0
    property real width: 0
    property real height: 0
    property int intersection: 0
    default property list<QtObject> data
}
