import QtQuick
import QtQuick.Window
import Quickshell
import qs.services

// Offscreen exercise of the real PanelLayout singleton.  Fake screen objects
// stand in for ShellScreen so the test can add, remove and re-add outputs
// without touching the running desktop.
Window {
    id: harness

    visible: true
    width: 120
    height: 80
    color: "#141218"

    property int failures: 0
    property int phase: 0

    function check(condition: bool, message: string): void {
        if (condition) {
            console.log(`  ok   ${message}`);
        } else {
            harness.failures++;
            console.error(`FAIL ${message}`);
        }
    }

    function screen(name: string, width: int, height: int, dpr: real, orientation: int): var {
        return {
            name: name,
            model: "Test Display",
            serialNumber: "SERIAL-" + name,
            x: 0,
            y: 0,
            width: width,
            height: height,
            devicePixelRatio: dpr,
            orientation: orientation,
            primaryOrientation: 0
        };
    }

    function run(): void {
        if (harness.phase === 0) {
            PanelLayout.reconcile([harness.screen("DP-1", 1920, 1080, 1, 0), harness.screen("HDMI-A-1", 2560, 1440, 1.5, 0)]);
            PanelLayout.setPosition("DP-1", "bar", {
                edge: "left",
                offsetX: 15
            });
            PanelLayout.setPosition("DP-1", "notifications", {
                anchor: "bottom-right",
                offsetX: 4
            });
            harness.phase = 1;
            settle.restart();
            return;
        }

        if (harness.phase === 1) {
            harness.check(PanelLayout.outputs["DP-1"] !== undefined, "an online output is recorded");
            harness.check(PanelLayout.placement("DP-1", "bar").edge === "left", "bar edge is restored");
            harness.check(PanelLayout.placement("DP-1", "notifications").anchor === "bottom-right", "notification anchor is restored");

            // Remove DP-1, then rotate/scale the remaining output. The offline
            // record must stay and the layout call must not throw.
            PanelLayout.reconcile([harness.screen("HDMI-A-1", 2560, 1440, 1.5, 1)]);
            harness.check(PanelLayout.outputs["DP-1"] !== undefined, "an offline output is retained");
            harness.check(PanelLayout.outputs["HDMI-A-1"].orientation === 1, "rotation reaches the state");

            PanelLayout.reconcile([harness.screen("DP-1", 3840, 2160, 2, 0)]);
            harness.check(PanelLayout.placement("DP-1", "bar").edge === "left", "reconnect restores the bar edge");
            harness.check(PanelLayout.placement("DP-1", "notifications").anchor === "bottom-right", "reconnect restores the panel anchor");

            harness.phase = 2;
            settle.restart();
            return;
        }

        console.log(`panel-layout QML checks: ${harness.failures} failures`);
        Qt.exit(harness.failures === 0 ? 0 : 1);
    }

    Timer {
        id: settle

        interval: 250
        onTriggered: harness.run()
    }

    Component.onCompleted: settle.start()
}
