import QtQuick
import Quickshell
import "ScreenModel.js" as Model
import "OutputLayout.js" as Layout

// Offscreen QML-engine check for the same JS modules the shell imports.  It
// simulates output removal without creating a real screen or a layer surface.
Item {
    id: harness

    property int failures: 0

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

    Component.onCompleted: {
        const first = Model.snapshot([
            harness.screen("DP-1", 1920, 1080, 1, 0),
            harness.screen("HDMI-A-1", 2560, 1440, 1.5, 0)
        ]);
        harness.check(first.outputs.length === 2, "two outputs are described");
        harness.check(Model.choosePrimary(first.outputs, {
            focusedName: "HDMI-A-1"
        }).name === "HDMI-A-1", "focused output becomes active");

        const removed = Model.snapshot([harness.screen("HDMI-A-1", 2560, 1440, 1.5, 0)]);
        const change = Model.diff(first, removed);
        harness.check(change.removed.length === 1 && change.removed[0].key === "DP-1", "removing an output is reported");
        harness.check(Model.choosePrimary(removed.outputs, {
            focusedName: "DP-1"
        }).name === "HDMI-A-1", "primary falls back after removal");

        let state = Layout.reconcile(Layout.emptyState(), first, 100);
        state = Layout.setPosition(state, "DP-1", "bar", {
            edge: "left",
            offsetX: 12
        });
        state = Layout.reconcile(state, Model.snapshot([harness.screen("DP-1", 2560, 1440, 1.5, 1)]), 200);
        const record = Layout.restore(state, "DP-1");
        harness.check(record.width === 2560 && record.devicePixelRatio === 1.5, "rotation and scale update geometry");
        harness.check(record.positions.bar.edge === "left" && record.positions.bar.offsetX === 12, "panel positions survive a reconnect");

        const empty = Model.snapshot([]);
        const last = Model.diff(removed, empty);
        harness.check(last.empty && last.removed.length === 1, "removing the last output is safe");
        harness.check(Model.choosePrimary(empty.outputs, {}) === null, "an empty model has no primary");

        console.log(`screen QML checks: ${harness.failures} failures`);
        finishTimer.start();
    }

    Timer {
        id: finishTimer

        interval: 100
        onTriggered: Qt.exit(harness.failures === 0 ? 0 : 1)
    }
}
