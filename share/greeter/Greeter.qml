import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Services.UPower

Item {
    id: root

    property string pendingPassword: ""
    property string prompt: ""
    property string errorText: ""
    property bool busy: false
    property bool passwordVisible: false
    property var users: []
    property date now: new Date()
    property string cpuLoad: "—"
    property int memPercent: 0
    property string hostName: ""
    property string kernel: ""
    property string uptime: ""

    readonly property var weekdays: ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"]
    readonly property var months: ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
    readonly property string fontFamily: gsf.status === FontLoader.Ready ? gsf.name : "sans-serif"

    readonly property color background: "#09080b"
    readonly property color surface: "#1a161d"
    readonly property color surfaceHigh: "#251f29"
    readonly property color foreground: "#f7f0f2"
    readonly property color muted: "#c6b8bf"
    readonly property color accent: "#e05263"
    readonly property color outline: "#4a3a44"

    readonly property int daysInMonth: new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
    readonly property int firstWeekday: new Date(now.getFullYear(), now.getMonth(), 1).getDay()
    readonly property string monthLabel: (months[now.getMonth()] + " " + now.getFullYear()).toUpperCase()
    readonly property int calendarCells: Math.ceil((firstWeekday + daysInMonth) / 7) * 7

    function dayText(index: int): string {
        const day = index - firstWeekday + 1;
        return day >= 1 && day <= daysInMonth ? "" + day : "";
    }

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
        cpuProcess.running = true;
        memProcess.running = true;
        systemProcess.running = true;
        passField.forceActiveFocus();
    }

    FontLoader {
        id: gsf
        source: "file:///etc/xdg/quickshell/caelestia/assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf"
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: {
            cpuProcess.running = true;
            memProcess.running = true;
            systemProcess.running = true;
        }
    }

    Process {
        id: userProcess
        command: ["sh", "-c", "getent passwd 2>/dev/null | awk -F: '$3 >= 1000 && $3 < 65534 { print $1 }'"]
        stdout: StdioCollector { id: userOutput }
        onExited: {
            const list = userOutput.text.trim().split("\n").filter(name => name.length > 0);
            root.users = list;
            if (list.length > 0 && userField.text.length === 0)
                userField.text = list[0];
            passField.forceActiveFocus();
        }
    }

    Process {
        id: cpuProcess
        command: ["sh", "-c", "awk '{print $1}' /proc/loadavg"]
        stdout: StdioCollector { id: cpuOutput }
        onExited: root.cpuLoad = cpuOutput.text.trim()
    }

    Process {
        id: memProcess
        command: ["sh", "-c", "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{if(t>0)printf \"%d\", (t-a)*100/t}' /proc/meminfo"]
        stdout: StdioCollector { id: memOutput }
        onExited: root.memPercent = parseInt(memOutput.text.trim()) || 0
    }

    Process {
        id: systemProcess
        command: ["sh", "-c", "printf '%s\\n' \"$(hostname)\" \"$(uname -r)\" \"$(uptime -p | sed 's/^up //')\""]
        stdout: StdioCollector { id: systemOutput }
        onExited: {
            const lines = systemOutput.text.trim().split("\n");
            root.hostName = lines[0] || "";
            root.kernel = lines[1] || "";
            root.uptime = lines[2] || "";
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
        function onLaunched() { root.busy = true; }
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

    RowLayout {
        anchors.fill: parent
        anchors.margins: 34
        spacing: 24

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 430
            Layout.alignment: Qt.AlignVCenter
            spacing: 18

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 28
                color: "#cc1a161d"
                border.width: 1
                border.color: root.outline
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#66000000"
                    shadowBlur: 0.5
                    shadowVerticalOffset: 8
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "CALENDÁRIO"
                            color: root.muted
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.letterSpacing: 1.5
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.monthLabel
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: root.outline
                        opacity: 0.55
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        columns: 7
                        columnSpacing: 2
                        rowSpacing: 2
                        Repeater {
                            model: ["D", "S", "T", "Q", "Q", "S", "S"]
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: root.muted
                                font.family: root.fontFamily
                                font.pixelSize: 10
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        columnSpacing: 2
                        rowSpacing: 2
                        Repeater {
                            model: root.calendarCells
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: index - root.firstWeekday + 1 === root.now.getDate() ? root.accent : "transparent"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: root.dayText(index)
                                    color: index - root.firstWeekday + 1 === root.now.getDate() ? "#19080b" : root.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    font.weight: index - root.firstWeekday + 1 === root.now.getDate() ? Font.Bold : Font.Normal
                                }
                            }
                        }
                    }
                }
            }
        }


        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 430
            spacing: 18

            Item { Layout.fillHeight: true }

        ColumnLayout {
            Layout.preferredWidth: 430
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4
                Text {
                    text: Qt.formatDateTime(root.now, "HH")
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Math.min(88, root.height * 0.1)
                    font.weight: Font.Light
                }
                Text {
                    text: Qt.formatDateTime(root.now, "mm")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Math.min(88, root.height * 0.1)
                    font.weight: Font.Light
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 12
                text: (root.weekdays[root.now.getDay()] + ", " + root.now.getDate() + " de " + root.months[root.now.getMonth()]).toUpperCase()
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 96
                implicitHeight: 96

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
                    font.family: root.fontFamily
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
                font.family: root.fontFamily
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
                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: 56
                radius: height / 2
                color: "#cc1a161d"
                border.width: 1
                border.color: passField.activeFocus ? root.accent : root.outline

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 10

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
                        font.family: root.fontFamily
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
                font.family: root.fontFamily
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
        }


            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 210
                radius: 28
                color: "#cc1a161d"
                border.width: 1
                border.color: root.outline
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#66000000"
                    shadowBlur: 0.5
                    shadowVerticalOffset: 8
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: "SISTEMA"
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        font.letterSpacing: 1.5
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.hostName
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.uptime
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: root.outline
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "Carga"; color: root.muted; font.family: root.fontFamily; font.pixelSize: 11 }
                            Text { text: root.cpuLoad; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 18; font.weight: Font.Medium }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 4
                                radius: 2
                                color: root.surfaceHigh
                                Rectangle {
                                    width: parent.width * Math.min(1, (parseFloat(root.cpuLoad) || 0) / 8)
                                    height: parent.height
                                    radius: 2
                                    color: root.accent
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "Memória"; color: root.muted; font.family: root.fontFamily; font.pixelSize: 11 }
                            Text { text: root.memPercent + "%"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 18; font.weight: Font.Medium }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 4
                                radius: 2
                                color: root.surfaceHigh
                                Rectangle {
                                    width: parent.width * Math.min(1, root.memPercent / 100)
                                    height: parent.height
                                    radius: 2
                                    color: root.accent
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "Bateria"; color: root.muted; font.family: root.fontFamily; font.pixelSize: 11 }
                            Text {
                                text: UPower.displayDevice.isLaptopBattery ? Math.round(UPower.displayDevice.percentage * 100) + "%" : "AC"
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.Medium
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 4
                                radius: 2
                                color: root.surfaceHigh
                                Rectangle {
                                    width: UPower.displayDevice.isLaptopBattery ? parent.width * UPower.displayDevice.percentage : 0
                                    height: parent.height
                                    radius: 2
                                    color: root.accent
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.fillWidth: true
                        text: root.kernel
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }

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
            font.family: root.fontFamily
            font.pixelSize: 12
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["/usr/bin/kill", "-TERM", "" + Quickshell.processId])
        }
    }
}
