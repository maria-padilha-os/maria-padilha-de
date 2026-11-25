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
    property bool passwordVisible: false
    property var users: []
    property date now: new Date()

    readonly property var weekdays: ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"]
    readonly property var months: ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
    readonly property color background: "#09080b"
    readonly property color surface: "#171319"
    readonly property color surfaceHigh: "#211a22"
    readonly property color foreground: "#f7f0f2"
    readonly property color muted: "#c6b8bf"
    readonly property color accent: "#e05263"
    readonly property color accentForeground: "#19080b"
    readonly property color outline: "#5a4650"

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
        passField.forceActiveFocus();
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
            passField.forceActiveFocus();
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
            Greetd.launch(["dbus-run-session", "--", "start-hyprland"], [
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

    // The lock screen's wallpaper. The installed copy can carry a wallpaper
    // next to this file; the repository falls back to the gradient below.
    Image {
        id: wallpaper
        anchors.fill: parent
        source: "wallpaper"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        visible: wallpaper.status !== Image.Ready

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#08070a" }
            GradientStop { position: 0.55; color: "#1b0e16" }
            GradientStop { position: 1.0; color: "#09080b" }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#09080b"
        opacity: 0.55
    }

    Rectangle {
        width: parent.width * 0.65
        height: width
        radius: width / 2
        x: -width * 0.35
        y: -height * 0.55
        color: "#3a1420"
        opacity: 0.35
    }

    Rectangle {
        width: parent.width * 0.5
        height: width
        radius: width / 2
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -width * 0.3
        anchors.bottomMargin: -height * 0.35
        color: "#2a1624"
        opacity: 0.35
    }

    Text {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 40
        text: "Maria Padilha"
        color: root.foreground
        font.pixelSize: 18
        font.weight: Font.Medium
    }

    ColumnLayout {
        id: center

        anchors.centerIn: parent
        width: Math.min(420, root.width - 80)
        spacing: 12

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: root.foreground
            font.pixelSize: Math.min(96, root.height * 0.11)
            font.weight: Font.Light
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 12
            text: (root.weekdays[root.now.getDay()] + ", " + root.now.getDate() + " de " + root.months[root.now.getMonth()]).toUpperCase()
            color: root.muted
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 104
            implicitHeight: 104
            radius: width / 2
            color: root.surfaceHigh
            border.width: 1
            border.color: root.outline

            Text {
                anchors.centerIn: parent
                text: userField.text.length > 0 ? userField.text.charAt(0).toUpperCase() : "?"
                color: root.foreground
                font.pixelSize: 42
                font.weight: Font.Medium
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: userField.text.length > 0 ? userField.text : "usuário"
            color: root.foreground
            font.pixelSize: 18
            font.weight: Font.Medium
        }

        TextField {
            id: userField

            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: root.users.length !== 1
            text: root.users.length > 0 ? root.users[0] : ""
            color: root.foreground
            placeholderText: "usuário"
            placeholderTextColor: root.muted
            horizontalAlignment: TextInput.AlignHCenter
            font.pixelSize: 15
            selectByMouse: true
            leftPadding: 14
            rightPadding: 14
            topPadding: 10
            bottomPadding: 10
            background: Rectangle {
                color: "#33000000"
                radius: 12
                border.width: 1
                border.color: userField.activeFocus ? root.accent : root.outline
            }
            onAccepted: passField.forceActiveFocus()
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
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
            horizontalAlignment: TextInput.AlignHCenter
            echoMode: root.passwordVisible ? TextInput.Normal : TextInput.Password
            font.pixelSize: 17
            selectByMouse: true
            leftPadding: 14
            rightPadding: 70
            topPadding: 12
            bottomPadding: 12
            background: Rectangle {
                color: "#44000000"
                radius: 14
                border.width: 1
                border.color: passField.activeFocus ? root.accent : root.outline
            }
            onAccepted: root.submit()

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: root.passwordVisible ? "ocultar" : "mostrar"
                color: root.muted
                font.pixelSize: 11

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.passwordVisible = !root.passwordVisible;
                        passField.forceActiveFocus();
                    }
                }
            }
        }

        Rectangle {
            id: enterButton

            Layout.fillWidth: true
            Layout.topMargin: 4
            implicitHeight: 46
            radius: 14
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
                    enterButton.forceActiveFocus();
                    root.submit();
                }
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.errorText.length > 0 ? root.errorText : (Greetd.available ? root.prompt : "greetd não está disponível")
            color: root.errorText.length > 0 ? "#f08a8a" : root.muted
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        z: 100
        implicitWidth: fallbackText.implicitWidth + 24
        implicitHeight: 32
        radius: 10
        color: root.surfaceHigh
        border.width: 1
        border.color: root.outline

        Accessible.role: Accessible.Button
        Accessible.name: "Usar o greeter de texto"
        Accessible.focusable: true
        Accessible.onPressAction: Qt.exit(1)

        Text {
            id: fallbackText
            anchors.centerIn: parent
            text: "Usar texto"
            color: root.muted
            font.pixelSize: 12
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["/usr/bin/kill", "-TERM", "" + Quickshell.processId])
        }
    }
}
