pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

Singleton {
    id: root

    property bool active: false
    property bool busy: false

    readonly property string script: `${Paths.home}/.config/hypr/utils/nightlight.sh`

    function hourOf(value: string): int {
        const hour = parseInt((value || "").split(":")[0], 10);
        return isNaN(hour) ? 0 : Math.max(0, Math.min(23, hour));
    }

    function wanted(nowHour: int): bool {
        const on = hourOf(GlobalConfig.services.nightLightOn);
        const off = hourOf(GlobalConfig.services.nightLightOff);
        return on <= off ? nowHour >= on && nowHour < off : nowHour >= on || nowHour < off;
    }

    function setActive(on: bool): void {
        if (busy || on === active)
            return;

        busy = true;
        setProc.command = ["sh", "-c", `exec "${script}" ${on ? "on" : "off"}`];
        setProc.running = true;
    }

    function tick(): void {
        if (!GlobalConfig.services.nightLightAuto)
            return;

        const want = wanted(new Date().getHours());
        if (want !== active)
            setActive(want);
    }

    // The schedule only changes on the hour. A minute-by-minute poll would
    // wake the shell 1,440 times a day for a value that changes twice.
    function scheduleTick(): void {
        if (!GlobalConfig.services.nightLightAuto) {
            tickTimer.stop();
            return;
        }

        const now = new Date();
        const nextHour = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours() + 1, 0, 0, 0);
        tickTimer.interval = Math.max(1000, nextHour.getTime() - now.getTime());
        tickTimer.restart();
    }

    Component.onCompleted: {
        statusProc.running = true;
        root.scheduleTick();
    }

    Connections {
        function onNightLightAutoChanged(): void {
            root.tick();
            root.scheduleTick();
        }

        function onNightLightOnChanged(): void {
            root.tick();
            root.scheduleTick();
        }

        function onNightLightOffChanged(): void {
            root.tick();
            root.scheduleTick();
        }

        target: GlobalConfig.services
    }

    Timer {
        id: tickTimer

        repeat: false
        running: false
        onTriggered: {
            root.tick();
            root.scheduleTick();
        }
    }

    Process {
        id: statusProc

        command: ["sh", "-c", `exec "${root.script}" status`]

        stdout: StdioCollector {
            onStreamFinished: root.active = text.trim() === "on"
        }
    }

    Process {
        id: setProc

        onExited: {
            root.busy = false;
            statusProc.running = true;
        }
    }
}
