import QtQuick
import QtQuick.Window
import Quickshell
import qs.components
import qs.components.controls
import qs.services

// Runs under `qs -p <temporary config>`. The runner copies only the shared
// controls this file needs and supplies a minimal Colours singleton, so the
// check never starts the live shell, a service or a network request.
Window {
    id: win

    readonly property bool expectReduced: (Quickshell.env("PADILHA_A11Y_EXPECT_REDUCED") || "0") === "1"
    property int failures: 0
    property int activations: 0

    width: 800
    height: 600
    visible: true

    function check(condition: bool, message: string): void {
        if (condition) {
            console.log("  ok   " + message);
        } else {
            console.error("  FAIL " + message);
            win.failures++;
        }
    }

    IconButton {
        id: iconButton

        icon: "settings"
        accessibleName: "Open test settings"
        accessibleDescription: "Loads the shared icon button"
        implicitWidth: 40
        implicitHeight: 40
    }

    SearchBar {
        id: search

        placeholderText: "Search something"
    }

    StyledSwitch {
        id: toggle

        text: "Enabled"
    }

    StyledRadioButton {
        id: radio

        text: "Option"
    }

    FocusRing {
        id: ring

        target: iconButton
    }

    Component.onCompleted: {
        iconButton.clicked.connect(function () {
            win.activations++;
        });
    }

    Timer {
        interval: 150
        running: true

        onTriggered: {
            win.check(typeof Accessibility.reducedMotion === "boolean", "Accessibility singleton loads");
            win.check(Accessibility.reducedMotion === win.expectReduced, "reduced-motion environment is honoured");
            win.check(Accessibility.motion(500) === (win.expectReduced ? 0 : 500), "motion duration follows the reduced-motion mode");
            win.check(iconButton.activeFocusOnTab === true, "icon button participates in tab order");
            win.check(iconButton.Accessible.name === "Open test settings", "icon button keeps its accessible name");
            win.check(iconButton.Accessible.description.length > 0, "icon button exposes its description");
            win.check(iconButton.Accessible.focusable === true, "icon button is exposed as focusable");
            win.check(search.Accessible.name === "Search something", "search field falls back to its placeholder");
            win.check(toggle.Accessible.name === "Enabled", "switch falls back to its text");
            win.check(radio.Accessible.name === "Option", "radio button falls back to its text");
            win.check(ring.target === iconButton, "focus ring binds to its target");
            iconButton.activate();
            win.check(win.activations === 1, "button activation emits clicked once");
            console.log("accessibility load checks: " + win.failures + " failures");
            Qt.exit(win.failures === 0 ? 0 : 1);
        }
    }
}
