import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// A small, keyboard-friendly file browser for the dashboard.
//
// Everything starts in `api.paths.home`; the only thing that touches the disk on
// startup is the FolderListModel listing of that directory. Nothing here reads
// file contents — names and metadata only.
Item {
    id: root

    property var api
    property bool active: true

    // The dashboard can stretch the tab far wider than a comfortable reading
    // width, so the panel is centered and capped instead of filling the screen.
    readonly property int maxContentWidth: 900

    // Tolerate the first frame(s), before the host assigns `api`.
    readonly property var palette: root.api && root.api.colours ? root.api.colours.palette : null

    readonly property color onSurface: palette ? palette.m3onSurface : "transparent"
    readonly property color muted: palette ? palette.m3onSurfaceVariant : "transparent"
    readonly property color surfaceLow: palette ? palette.m3surfaceContainerLow : "transparent"
    readonly property color surfaceHigh: palette ? palette.m3surfaceContainerHigh : "transparent"
    readonly property color outlineVariant: palette ? palette.m3outlineVariant : "transparent"
    readonly property color accent: palette ? palette.m3primary : "transparent"
    readonly property color primaryContainer: palette ? palette.m3primaryContainer : "transparent"
    readonly property color onPrimaryContainer: palette ? palette.m3onPrimaryContainer : "transparent"
    readonly property color onErrorContainer: palette ? palette.m3onErrorContainer : "transparent"
    readonly property color errorContainer: palette ? palette.m3errorContainer : "transparent"

    readonly property string homePath: root.normalisePath(root.api && root.api.paths ? root.api.paths.home : "")

    property string currentPath: ""
    property var history: []
    property int historyIndex: -1
    property bool showHidden: false
    property bool readError: false
    property bool started: false

    // Exposed for the runtime probe (and useful for tests).
    readonly property int count: folderModel.count

    readonly property bool canGoBack: root.historyIndex > 0
    readonly property bool canGoForward: root.historyIndex >= 0 && root.historyIndex < root.history.length - 1
    readonly property string parentPath: root.parentOf(root.currentPath)
    readonly property bool canGoUp: root.currentPath.length > 0 && root.parentPath !== root.currentPath
    readonly property bool atHome: root.homePath.length > 0 && root.currentPath === root.homePath

    readonly property bool emptyState: root.started && folderModel.status === FolderListModel.Ready && folderModel.count === 0 && !root.readError && !accessProc.running

    readonly property string displayPath: {
        if (root.currentPath.length === 0)
            return "";
        if (root.homePath.length > 0) {
            if (root.currentPath === root.homePath)
                return "~";
            if (root.currentPath.startsWith(root.homePath + "/"))
                return "~" + root.currentPath.slice(root.homePath.length);
        }
        return root.currentPath;
    }

    implicitWidth: 760
    implicitHeight: 480

    // --- Paths and history --------------------------------------------------

    function normalisePath(path) {
        let value = String(path ?? "");
        if (value.length > 1)
            value = value.replace(/\/+$/, "");
        return value;
    }

    function toFileUrl(path) {
        const value = root.normalisePath(path);
        if (value.length === 0)
            return "";
        if (value.startsWith("file://"))
            return value;
        return "file://" + value.split("/").map(encodeURIComponent).join("/");
    }

    function parentOf(path) {
        const value = root.normalisePath(path);
        if (value.length === 0 || value === "/")
            return value;
        const slash = value.lastIndexOf("/");
        return slash <= 0 ? "/" : value.slice(0, slash);
    }

    function init() {
        if (root.started || root.homePath.length === 0)
            return;
        root.started = true;
        root.history = [root.homePath];
        root.historyIndex = 0;
        root.currentPath = root.homePath;
        fileList.currentIndex = 0;
        if (root.active)
            fileList.forceActiveFocus();
    }

    function navigate(path) {
        const target = root.normalisePath(path);
        if (!root.started || target.length === 0 || target === root.currentPath)
            return;

        const nextHistory = root.history.slice(0, root.historyIndex + 1);
        nextHistory.push(target);
        root.history = nextHistory;
        root.historyIndex = nextHistory.length - 1;
        root.currentPath = target;
        root.checkAccess();
    }

    function goBack() {
        if (!root.canGoBack)
            return;
        root.historyIndex -= 1;
        root.currentPath = root.history[root.historyIndex];
        root.checkAccess();
    }

    function goForward() {
        if (!root.canGoForward)
            return;
        root.historyIndex += 1;
        root.currentPath = root.history[root.historyIndex];
        root.checkAccess();
    }

    function goUp() {
        if (root.canGoUp)
            root.navigate(root.parentPath);
    }

    function goHome() {
        if (root.homePath.length > 0)
            root.navigate(root.homePath);
    }

    // FolderListModel does not re-list when `folder` is assigned the same URL.
    // Clearing it for one event-loop turn forces a fresh scan.
    function refresh() {
        if (!root.started || root.currentPath.length === 0)
            return;
        root.readError = false;
        folderModel.folder = "";
        Qt.callLater(function () {
            if (root.started && root.currentPath.length > 0)
                folderModel.folder = root.toFileUrl(root.currentPath);
        });
        root.checkAccess();
    }

    // --- Reading and opening ------------------------------------------------

    function checkAccess() {
        if (root.currentPath.length === 0)
            return;
        if (accessProc.running) {
            accessProc.nextPath = root.currentPath;
            return;
        }
        accessProc.checkPath = root.currentPath;
        accessProc.nextPath = "";
        accessProc.running = true;
    }

    function activateIndex(index) {
        if (index < 0 || index >= folderModel.count)
            return;
        const path = folderModel.get(index, "filePath");
        if (!path)
            return;
        if (folderModel.get(index, "fileIsDir"))
            root.navigate(path);
        else
            root.openFile(path);
    }

    function openFile(path) {
        openProc.command = ["xdg-open", String(path)];
        openProc.running = true;
    }

    function moveSelection(delta) {
        const total = folderModel.count;
        if (total <= 0)
            return;
        let index = fileList.currentIndex;
        if (index < 0)
            index = delta > 0 ? -1 : total;
        index = Math.max(0, Math.min(total - 1, index + delta));
        fileList.currentIndex = index;
        fileList.positionViewAtIndex(index, ListView.Contain);
    }

    // --- Metadata formatting ------------------------------------------------

    function formatSize(bytes) {
        const value = Number(bytes);
        if (!isFinite(value) || value < 0)
            return "";
        if (value < 1024)
            return value + " B";

        const units = ["KB", "MB", "GB", "TB", "PB"];
        let size = value / 1024;
        let unit = 0;
        while (size >= 1024 && unit < units.length - 1) {
            size /= 1024;
            unit += 1;
        }
        return (size >= 10 ? size.toFixed(0) : size.toFixed(1)) + " " + units[unit];
    }

    function formatDate(value) {
        if (!value)
            return "";
        const date = value instanceof Date ? value : new Date(value);
        if (isNaN(date.getTime()))
            return "";
        const sameYear = date.getFullYear() === new Date().getFullYear();
        return Qt.formatDateTime(date, sameYear ? "MMM d, HH:mm" : "MMM d, yyyy");
    }

    function suffixOf(name) {
        const value = String(name ?? "");
        const dot = value.lastIndexOf(".");
        return dot > 0 ? value.slice(dot + 1).toLowerCase() : "";
    }

    function fileIcon(name) {
        const suffix = root.suffixOf(name);

        switch (suffix) {
        case "png":
        case "jpg":
        case "jpeg":
        case "gif":
        case "webp":
        case "svg":
        case "bmp":
        case "tif":
        case "tiff":
        case "ico":
        case "avif":
        case "heic":
            return Quickshell.iconPath("image-x-generic", "application-x-zerosize");
        case "mp3":
        case "flac":
        case "ogg":
        case "wav":
        case "m4a":
        case "opus":
        case "aac":
        case "wma":
            return Quickshell.iconPath("audio-x-generic", "application-x-zerosize");
        case "mp4":
        case "mkv":
        case "avi":
        case "mov":
        case "webm":
        case "m4v":
        case "flv":
        case "wmv":
            return Quickshell.iconPath("video-x-generic", "application-x-zerosize");
        case "pdf":
            return Quickshell.iconPath("application-pdf", "application-x-zerosize");
        case "zip":
        case "tar":
        case "gz":
        case "bz2":
        case "xz":
        case "zst":
        case "7z":
        case "rar":
        case "tgz":
            return Quickshell.iconPath("package-x-generic", "application-x-zerosize");
        case "doc":
        case "docx":
        case "odt":
        case "rtf":
            return Quickshell.iconPath("x-office-document", "application-x-zerosize");
        case "xls":
        case "xlsx":
        case "ods":
        case "csv":
            return Quickshell.iconPath("x-office-spreadsheet", "application-x-zerosize");
        case "ppt":
        case "pptx":
        case "odp":
            return Quickshell.iconPath("x-office-presentation", "application-x-zerosize");
        case "ttf":
        case "otf":
        case "woff":
        case "woff2":
            return Quickshell.iconPath("font-x-generic", "application-x-zerosize");
        default:
            return Quickshell.iconPath("text-x-generic", "application-x-zerosize");
        }
    }

    // --- Model ---------------------------------------------------------------

    FolderListModel {
        id: folderModel

        folder: ""
        showDirs: true
        showFiles: true
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: root.showHidden
        sortField: FolderListModel.Name
        sortReversed: false
        sortCaseSensitive: false
    }

    onCurrentPathChanged: {
        if (!root.started)
            return;
        root.readError = false;
        folderModel.folder = root.toFileUrl(root.currentPath);
        fileList.currentIndex = 0;
    }

    Component.onCompleted: root.init()
    onApiChanged: root.init()
    onActiveChanged: {
        if (root.active)
            fileList.forceActiveFocus();
    }

    Connections {
        target: folderModel

        function onCountChanged() {
            if (folderModel.count === 0)
                fileList.currentIndex = -1;
            else if (fileList.currentIndex < 0)
                fileList.currentIndex = 0;
        }
    }

    // --- Visuals -------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: root.surfaceLow
        border.width: 1
        border.color: root.outlineVariant
    }

    Item {
        id: panel

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width, root.maxContentWidth)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    iconName: "go-up"
                    fallbackName: "go-up"
                    enabled: root.canGoUp
                    hoverColour: root.surfaceHigh
                    checkedColour: root.primaryContainer
                    onActivated: root.goUp()
                }

                IconButton {
                    iconName: "go-home"
                    fallbackName: "go-home"
                    enabled: root.homePath.length > 0 && !root.atHome
                    hoverColour: root.surfaceHigh
                    checkedColour: root.primaryContainer
                    onActivated: root.goHome()
                }

                IconButton {
                    iconName: "go-previous"
                    fallbackName: "go-previous"
                    enabled: root.canGoBack
                    hoverColour: root.surfaceHigh
                    checkedColour: root.primaryContainer
                    onActivated: root.goBack()
                }

                IconButton {
                    iconName: "go-next"
                    fallbackName: "go-next"
                    enabled: root.canGoForward
                    hoverColour: root.surfaceHigh
                    checkedColour: root.primaryContainer
                    onActivated: root.goForward()
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 40
                    Layout.alignment: Qt.AlignVCenter
                    text: root.displayPath
                    color: root.onSurface
                    font: Tokens.font.body.medium
                    elide: Text.ElideMiddle
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    id: hiddenButton

                    Layout.preferredWidth: hiddenRow.implicitWidth + Tokens.padding.medium * 2
                    Layout.preferredHeight: 34
                    radius: Tokens.rounding.full
                    color: root.showHidden ? root.primaryContainer : hiddenMouse.containsMouse ? root.surfaceHigh : "transparent"

                    RowLayout {
                        id: hiddenRow

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.extraSmall

                        Image {
                            source: Quickshell.iconPath(root.showHidden ? "view-visible" : "view-hidden", "view-hidden")
                            sourceSize.width: 16
                            sourceSize.height: 16
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            text: Tr.tr("Hidden")
                            color: root.showHidden ? root.onPrimaryContainer : root.muted
                            font: Tokens.font.label.medium
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: hiddenMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showHidden = !root.showHidden;
                            fileList.currentIndex = 0;
                        }
                    }
                }

                IconButton {
                    iconName: "view-refresh"
                    fallbackName: "view-refresh"
                    enabled: root.started
                    hoverColour: root.surfaceHigh
                    checkedColour: root.primaryContainer
                    onActivated: root.refresh()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.outlineVariant
                opacity: 0.6
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                visible: root.readError
                radius: Tokens.rounding.small
                color: root.errorContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    Image {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        source: Quickshell.iconPath("dialog-error", "dialog-warning")
                        sourceSize.width: 18
                        sourceSize.height: 18
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Tr.tr("Cannot read this folder")
                        color: root.onErrorContainer
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: fileList

                    anchors.fill: parent
                    visible: !root.readError
                    clip: true
                    focus: root.active
                    currentIndex: -1
                    boundsBehavior: Flickable.StopAtBounds
                    model: folderModel

                    Keys.onUpPressed: (event) => {
                        root.moveSelection(-1);
                        event.accepted = true;
                    }
                    Keys.onDownPressed: (event) => {
                        root.moveSelection(1);
                        event.accepted = true;
                    }
                    Keys.onReturnPressed: (event) => {
                        root.activateIndex(fileList.currentIndex);
                        event.accepted = true;
                    }
                    Keys.onEnterPressed: (event) => {
                        root.activateIndex(fileList.currentIndex);
                        event.accepted = true;
                    }
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Backspace) {
                            root.goUp();
                            event.accepted = true;
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        id: verticalBar

                        policy: ScrollBar.AsNeeded
                        width: 8

                        contentItem: Rectangle {
                            implicitWidth: 4
                            implicitHeight: 20
                            radius: 2
                            color: root.muted
                            opacity: verticalBar.pressed ? 1 : 0.5
                        }

                        background: Item {}
                    }

                    delegate: Rectangle {
                        id: row

                        required property int index
                        required property string fileName
                        required property bool fileIsDir
                        required property var fileSize
                        required property var fileModified

                        readonly property bool isDir: row.fileIsDir
                        readonly property bool isCurrent: fileList.currentIndex === row.index

                        width: fileList.width
                        height: 38
                        radius: Tokens.rounding.small
                        color: row.isCurrent ? Qt.alpha(root.accent, 0.16) : rowMouse.containsMouse ? root.surfaceHigh : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.small
                            anchors.rightMargin: Tokens.padding.medium + 8
                            spacing: Tokens.spacing.small

                            Image {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                source: row.isDir ? Quickshell.iconPath("folder", "inode-directory") : root.fileIcon(row.fileName)
                                sourceSize.width: 18
                                sourceSize.height: 18
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: row.fileName
                                color: root.onSurface
                                font: Tokens.font.body.medium
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                visible: !row.isDir
                                Layout.preferredWidth: 70
                                horizontalAlignment: Text.AlignRight
                                text: row.isDir ? "" : root.formatSize(row.fileSize)
                                color: root.muted
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                visible: !row.isDir
                                Layout.preferredWidth: 116
                                horizontalAlignment: Text.AlignRight
                                text: row.isDir ? "" : root.formatDate(row.fileModified)
                                color: root.muted
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: rowMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                fileList.currentIndex = row.index;
                                fileList.forceActiveFocus();
                            }
                            onDoubleClicked: root.activateIndex(row.index)
                        }
                    }
                }

                Item {
                    anchors.centerIn: parent
                    width: Math.max(emptyIcon.width, emptyLabel.implicitWidth)
                    height: emptyIcon.height + Tokens.spacing.small + emptyLabel.implicitHeight
                    visible: root.emptyState

                    Image {
                        id: emptyIcon

                        anchors.horizontalCenter: parent.horizontalCenter
                        source: Quickshell.iconPath("folder-open", "folder")
                        sourceSize.width: 48
                        sourceSize.height: 48
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        opacity: 0.7
                    }

                    Text {
                        id: emptyLabel

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: emptyIcon.bottom
                        anchors.topMargin: Tokens.spacing.small
                        text: Tr.tr("This folder is empty")
                        color: root.muted
                        font: Tokens.font.body.medium
                    }
                }
            }
        }
    }

    // --- Processes -----------------------------------------------------------

    // Opening a file is explicit: double-click or Enter, never a single click.
    Process {
        id: openProc

        command: ["xdg-open", ""]

        onExited: (exitCode) => {
            if (exitCode !== 0)
                console.warn("Files: xdg-open exited with status", exitCode);
        }
    }

    // FolderListModel cannot distinguish an empty folder from a folder it was
    // not allowed to read, so ask `test` when the user navigates. This never
    // runs on startup: the initial home listing is the only startup activity.
    Process {
        id: accessProc

        property string checkPath: ""
        property string nextPath: ""

        command: ["test", "-d", accessProc.checkPath, "-a", "-r", accessProc.checkPath]

        onExited: (exitCode) => {
            if (accessProc.checkPath === root.currentPath)
                root.readError = exitCode !== 0;

            if (accessProc.nextPath.length > 0) {
                const next = accessProc.nextPath;
                accessProc.nextPath = "";
                if (next !== accessProc.checkPath) {
                    accessProc.checkPath = next;
                    accessProc.running = true;
                }
            }
        }
    }

    component IconButton: Rectangle {
        id: button

        property string iconName: ""
        property string fallbackName: "image-missing"
        property bool checked: false
        property color hoverColour: "transparent"
        property color checkedColour: "transparent"

        signal activated()

        implicitWidth: 34
        implicitHeight: 34
        radius: Tokens.rounding.full
        color: !button.enabled ? "transparent" : button.checked ? button.checkedColour : buttonMouse.containsMouse ? button.hoverColour : "transparent"
        opacity: button.enabled ? 1 : 0.35

        Image {
            anchors.centerIn: parent
            source: Quickshell.iconPath(button.iconName, button.fallbackName)
            sourceSize.width: 18
            sourceSize.height: 18
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.activated()
        }
    }
}
