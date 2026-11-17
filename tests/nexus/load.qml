import QtQuick
import QtQuick.Window
import Quickshell
import "SearchRanking.js" as Ranking
import "FocusNavigation.js" as Focus

// Offscreen QML loading check. It exercises the same JS modules imported by the
// search UI and instantiates the generic FocusRing; it deliberately does not
// load the full shell services, so it can run on a headless CI host.
Window {
    id: harness

    visible: true
    width: 240
    height: 120
    color: "#141218"

    property int failures: 0

    function check(condition: bool, message: string): void {
        if (condition) {
            console.log(`  ok   ${message}`);
        } else {
            harness.failures++;
            console.error(`FAIL ${message}`);
        }
    }

    Component.onCompleted: {
        const entries = [
            { kind: "setting", label: "Night light", description: "Warm tint", pageTitle: "Display", order: 0 },
            { kind: "page", label: "Display", description: "Brightness", pageTitle: "Display", order: 1 }
        ];
        const results = Ranking.rank(entries, "night");
        harness.check(results.length === 1 && results[0].label === "Night light", "ranking loads in the QML engine");
        harness.check(Focus.step(-1, 2, 1) === 0, "focus transitions load in the QML engine");

        const ringPath = Quickshell.env("PADILHA_NEXUS_FOCUS_RING") || "";
        if (ringPath.length === 0) {
            harness.failures++;
            console.error("PADILHA_NEXUS_FOCUS_RING is empty");
        } else {
            const component = Qt.createComponent("file://" + ringPath, Component.PreferSynchronous);
            if (component.status !== Component.Ready) {
                harness.failures++;
                console.error(`FocusRing loads: ${component.errorString()}`);
            } else {
                const target = Qt.createQmlObject("import QtQuick; Item { width: 20; height: 20 }", harness);
                const ring = component.createObject(harness, {
                    target: target,
                    colour: "#D0BCFF"
                });
                harness.check(ring !== null && ring.objectName === "settingsFocusRing", "FocusRing instantiates");
                if (ring)
                    ring.destroy();
                target.destroy();
            }
        }

        console.log(`QML load checks: ${harness.failures} failures`);
        finishTimer.start();
    }

    Timer {
        id: finishTimer

        interval: 150
        onTriggered: Qt.exit(harness.failures === 0 ? 0 : 1)
    }
}
