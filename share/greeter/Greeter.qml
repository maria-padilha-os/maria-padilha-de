import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

Item {
    id: root

    property string pendingPassword: ""
    property string prompt: ""
    property string errorText: ""
    property bool busy: false
    property var users: []
    property date now: new Date()

    readonly property color background: "#09080b"
    readonly property color surface: "#171319"
    readonly property color surfaceHigh: "#211a22"
    readonly property color foreground: "#f7f0f2"
    readonly property color muted: "#b6a9b0"
    readonly property color accent: "#e05263"
    readonly property color accentForeground: "#19080b"
    readonly property color outline: "#46343d"

    function submit(): void {
        if (root.busy || !Greetd.available)
            return;
        const user = userField.text.trim();
        if (user.length === 0) {
            root.errorText = "Informe o usuário.";
            return;
        }
        root.pendingPassword = passField.text;
        passField.text = "";
        root.errorText = "";
        root.prompt = "";
        root.busy = true;
        Greetd.createSession(user);
    }

    Component.onCompleted: {
        userProcess.running = true;
        userField.forceActiveFocus();
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    Process {
        id: userProcess

        command: ["sh", "-c", "getent passwd 2>/dev/null | awk -F: '$3 >= 1000 && $3 < 65534 { print $1 }'"]

        stdout: StdioCollector {
            id: userOutput
        }

        onExited: {
            const list = userOutput.text.trim().split("\n").filter(name => name.length > 0);
            root.users = list;
            if (list.length > 0 && userField.text.length === 0)
                userField.text = list[0];
            userField.forceActiveFocus();
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            root.prompt = message;
            if (responseRequired) {
                const response = root.pendingPassword;
                root.pendingPassword = "";
                Greetd.respond(response);
            }
        }

        function onAuthFailure(message) {
            root.busy = false;
            root.errorText = message || "Não foi possível autenticar.";
            passField.forceActiveFocus();
        }

        function onReadyToLaunch() {
            root.busy = true;
            Greetd.launch(["dbus-run-session", "--", "hyprland"], [
                "XDG_SESSION_TYPE=wayland",
                "XDG_CURRENT_DESKTOP=Hyprland",
                "XDG_SESSION_DESKTOP=Hyprland",
                "XDG_SESSION_CLASS=user"
            ]);
        }

        function onLaunched() {
            root.busy = true;
        }

        function onError(error) {
            root.busy = false;
            root.errorText = error || "Erro ao falar com o greetd.";
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.background

        Rectangle {
            width: parent.width * 0.7
            height: width
            radius: width / 2
            x: -width * 0.25
            y: -height * 0.45
            color: "#2a1018"
            opacity: 0.65
        }

        Rectangle {
            width: parent.width * 0.45
            height: width
            radius: width / 2
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -width * 0.2
            anchors.bottomMargin: -height * 0.35
            color: "#241521"
            opacity: 0.7
        }

        Column {
            anchors.fill: parent
            anchors.margins: 48

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 24
                text: Qt.formatDateTime(root.now, "HH:mm")
                color: root.foreground
                font.pixelSize: 68
                font.weight: Font.Light
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.now, "dddd, d 'de' MMMM")
                color: root.muted
                font.pixelSize: 16
            }
        }

        Rectangle {
            id: card

            width: 430
            implicitHeight: content.implicitHeight + 64
            anchors.centerIn: parent
            radius: 28
            color: root.surface
            border.width: 1
            border.color: root.outline

            ColumnLayout {
                id: content

                anchors.fill: parent
                anchors.margins: 32
                spacing: 12

                Text {
                    text: "Maria Padilha"
                    color: root.foreground
                    font.pixelSize: 28
                    font.weight: Font.Medium
                }

                Text {
                    text: Greetd.available ? "Bem-vindo de volta" : "greetd não está disponível"
                    color: root.muted
                    font.pixelSize: 14
                }

                Item {
                    Layout.preferredHeight: 8
                }

                Text {
                    text: "Usuário"
                    color: root.muted
                    font.pixelSize: 12
                }

                TextField {
                    id: userField

                    Layout.fillWidth: true
                    text: root.users.length > 0 ? root.users[0] : ""
                    color: root.foreground
                    placeholderText: "nome de usuário"
                    placeholderTextColor: root.muted
                    font.pixelSize: 16
                    selectByMouse: true
                    leftPadding: 14
                    rightPadding: 14
                    topPadding: 10
                    bottomPadding: 10
                    background: Rectangle {
                        color: root.surfaceHigh
                        radius: 12
                        border.width: 1
                        border.color: userField.activeFocus ? root.accent : root.outline
                    }
                    onAccepted: passField.forceActiveFocus()
                }

                Text {
                    text: "Senha"
                    color: root.muted
                    font.pixelSize: 12
                }

                TextField {
                    id: passField

                    Layout.fillWidth: true
                    color: root.foreground
                    placeholderText: "senha"
                    placeholderTextColor: root.muted
                    echoMode: TextInput.Password
                    font.pixelSize: 16
                    selectByMouse: true
                    leftPadding: 14
                    rightPadding: 14
                    topPadding: 10
                    bottomPadding: 10
                    background: Rectangle {
                        color: root.surfaceHigh
                        radius: 12
                        border.width: 1
                        border.color: passField.activeFocus ? root.accent : root.outline
                    }
                    onAccepted: root.submit()
                }

                Rectangle {
                    id: button

                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    implicitHeight: 44
                    radius: 12
                    color: root.busy ? root.surfaceHigh : root.accent
                    opacity: root.busy ? 0.7 : 1
                    activeFocusOnTab: !root.busy

                    Accessible.role: Accessible.Button
                    Accessible.name: "Entrar"
                    Accessible.focusable: true
                    Accessible.onPressAction: root.submit()

                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                    Keys.onSpacePressed: root.submit()

                    Text {
                        anchors.centerIn: parent
                        text: root.busy ? "Entrando..." : "Entrar"
                        color: root.accentForeground
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            button.forceActiveFocus();
                            root.submit();
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.errorText.length > 0 ? root.errorText : root.prompt
                    color: root.errorText.length > 0 ? "#f08a8a" : root.muted
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
