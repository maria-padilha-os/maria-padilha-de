pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia.I18n

// The update list is read-only until the page confirms. The helper still
// requires --yes, so a missing UI or a stale binding cannot start an upgrade
// by accident. There is no timer and no reboot path here.
Singleton {
    id: root

    readonly property string helper: Quickshell.env("PADILHA_UPDATE") || "padilha-update"

    property var updates: []
    property var summary: ({})
    property var checkWarnings: []
    property bool checking: false
    property bool applying: false
    property bool hasChecked: false
    property string error: ""

    property bool applyOK: false
    property bool lastApplyFailed: false
    property string applyError: ""
    property string applyMessage: ""
    property string logPath: ""
    property string logTail: ""

    readonly property bool hasUpdates: root.updates.length > 0
    readonly property bool batteryPresent: (UPower.displayDevice?.ready ?? false) && (UPower.displayDevice?.isLaptopBattery ?? false)
    readonly property int batteryPercent: Math.round((UPower.displayDevice?.percentage ?? 0) * 100)
    readonly property bool onAc: !UPower.onBattery

    readonly property var warnings: {
        const codes = [];
        const low = Number(root.summary.lowBatteryPercent ?? 20);
        if (root.batteryPresent && root.batteryPercent <= low)
            codes.push("battery-low");
        if (root.batteryPresent && !root.onAc && root.summary.large === true)
            codes.push("not-on-ac-large");

        if (!UPower.displayDevice?.ready)
            return root.checkWarnings ?? [];
        return codes;
    }

    function parseJson(text: string): var {
        try {
            return JSON.parse(text);
        } catch (error) {
            return null;
        }
    }

    function check(): void {
        if (root.checking || root.applying)
            return;

        root.checking = true;
        root.error = "";
        checkProc.running = true;
    }

    function apply(confirmed: bool): void {
        if (confirmed !== true) {
            root.applyError = Tr.tr("Refusing to apply updates without confirmation.");
            root.lastApplyFailed = true;
            return;
        }
        if (root.applying || !root.hasUpdates)
            return;

        root.applying = true;
        root.applyOK = false;
        root.lastApplyFailed = false;
        root.applyError = "";
        root.applyMessage = "";
        root.logPath = "";
        root.logTail = "";
        applyProc.running = true;
    }

    function finishCheck(code: int): void {
        root.checking = false;
        const data = root.parseJson(checkOut.text);
        if (!data || !Array.isArray(data.updates)) {
            root.updates = [];
            root.summary = ({});
            root.checkWarnings = [];
            root.error = checkErr.text.trim() || Tr.tr("Could not read the update list.");
            return;
        }

        root.updates = data.updates;
        root.summary = data;
        root.checkWarnings = data.warnings ?? [];
        root.hasChecked = true;
        if (code !== 0)
            root.error = checkErr.text.trim() || Tr.tr("The update check failed.");
    }

    function finishApply(code: int): void {
        root.applying = false;
        const data = root.parseJson(applyOut.text);
        if (!data) {
            root.applyOK = false;
            root.lastApplyFailed = true;
            root.applyError = applyErr.text.trim() || Tr.tr("The update command returned no result (exit %1).").arg(code);
            return;
        }

        root.applyOK = data.ok === true;
        root.lastApplyFailed = !root.applyOK;
        root.applyMessage = String(data.message ?? "");
        root.logPath = String(data.logPath ?? "");
        root.logTail = String(data.logTail ?? "");
        if (!root.applyOK)
            root.applyError = root.applyMessage || Tr.tr("The update command failed.");
        else {
            root.updates = [];
            root.summary = ({
                    count: 0,
                    downloadLabel: "0 B",
                    installLabel: "0 B",
                    large: false
                });
            root.checkWarnings = [];
        }
    }

    Process {
        id: checkProc

        command: [root.helper, "check", "--json"]
        stdout: StdioCollector {
            id: checkOut
        }
        stderr: StdioCollector {
            id: checkErr
        }
        onExited: code => root.finishCheck(code) // qmllint disable signal-handler-parameters
    }

    Process {
        id: applyProc

        command: [root.helper, "apply", "--yes", "--json"]
        stdout: StdioCollector {
            id: applyOut
        }
        stderr: StdioCollector {
            id: applyErr
        }
        onExited: code => root.finishApply(code) // qmllint disable signal-handler-parameters
    }
}
