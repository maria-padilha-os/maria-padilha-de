import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
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

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#08070a" }
            GradientStop { position: 0.55; color: "#1b0e16" }
            GradientStop { position: 1.0; color: "#09080b" }
        }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: "wallpaper"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: status === Image.Ready
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.7
            blurMax: 64
            saturation: 0.85
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.background
        opacity: 0.45
    }

    ColumnLayout {
        id: center

        anchors.centerIn: parent
        width: Math.min(430, root.width - 80)
        spacing: 14

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            Text {
                text: Qt.formatDateTime(root.now, "HH")
                color: root.accent
                font.pixelSize: Math.min(104, root.height * 0.12)
                font.weight: Font.Light
            }

            Text {
                text: Qt.formatDateTime(root.now, "mm")
                color: root.foreground
                font.pixelSize: Math.min(104, root.height * 0.12)
                font.weight: Font.Light
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 18
            text: (root.weekdays[root.now.getDay()] + ", " + root.now.getDate() + " de " + root.months[root.now.getMonth()]).toUpperCase()
            color: root.muted
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 112
            implicitHeight: 112

            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: width / 2
                visible: false
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.surfaceHigh
                border.width: 1
                border.color: root.outline
                visible: face.status !== Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                text: userField.text.length > 0 ? userField.text.charAt(0).toUpperCase() : "?"
                color: root.foreground
                font.pixelSize: 44
                font.weight: Font.Medium
            }

            Image {
                id: face
                anchors.fill: parent
                source: "face"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: avatarMask
                }
            }
        }

        TextField {
            id: userField

            Layout.fillWidth: true
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
                radius: 22
                border.width: 1
                border.color: userField.activeFocus ? root.accent : root.outline
            }
            onAccepted: passField.forceActiveFocus()
        }

        Rectangle {
            id: passwordPill

            Layout.fillWidth: true
            Layout.topMargin: 4
            implicitHeight: 58
            radius: height / 2
            color: "#66171319"
            border.width: 1
            border.color: passField.activeFocus ? root.accent : root.outline

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: root.passwordVisible ? "visibility_off" : "lock"
                    color: root.muted
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 23

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.passwordVisible = !root.passwordVisible
                    }
                }

                TextField {
                    id: passField

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.foreground
                    placeholderText: "Senha"
                    placeholderTextColor: root.muted
                    echoMode: root.passwordVisible ? TextInput.Normal : TextInput.Password
                    font.pixelSize: 17
                    selectByMouse: true
                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0
                    background: null
                    onAccepted: root.submit()
                }

                Text {
                    text: "arrow_forward"
                    color: root.accent
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 25

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit()
                    }
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
        Accessible.onPressAction: Quickshell.execDetached(["/usr/bin/kill", "-TERM", "" + Quickshell.processId])

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
