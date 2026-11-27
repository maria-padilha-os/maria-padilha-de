pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import qs.components
import qs.services

Singleton {
    id: root

    property ShellRoot shellRoot

    // A detached state keeps shortcuts and IPC callable for the short window
    // after the last output is removed.  It has no screen and therefore no
    // window, but writes to it are harmless instead of dereferencing null.
    readonly property ScreenState detached: ScreenState {}

    function anySidebarOpen(): bool {
        return states.instances.some(s => s.sidebar);
    }

    function forScreen(screen: ShellScreen): ScreenState {
        if (!screen)
            return null;

        // Compare the connector key, not QObject identity: Quickshell replaces
        // the ShellScreen object when a monitor is reconnected.
        const key = Screens.keyFor(screen);
        for (const s of states.instances)
            if (s.modelData === screen || (key && s.outputName === key))
                return s;
        return null;
    }

    function forActive(): ScreenState {
        // Screens.focused already falls back to the primary when Hyprland's
        // focused monitor is stale or has just disappeared.
        const focused = Screens.focused;
        if (focused) {
            const state = forScreen(focused);
            if (state)
                return state;
        }

        return detached;
    }

    function componentsFor(screen: ShellScreen): Components {
        if (!screen)
            return null;

        for (const c of components.instances)
            if (c.modelData === screen)
                return c;
        return null;
    }

    function componentsForActive(): Components {
        const focused = Screens.focused;
        return focused ? componentsFor(focused) : null;
    }

    function restoreAssistant(): void {
        if (!AssistantSettings.open)
            return;
        const state = root.forActive();
        if (state && !state.assistant)
            state.assistant = true;
    }

    Component.onCompleted: {
        PanelLayout.reconcile(Screens.screens);
        Qt.callLater(root.restoreAssistant);
    }

    Timer {
        interval: 500
        repeat: false
        running: true
        onTriggered: root.restoreAssistant()
    }

    Variants {
        id: states

        model: Screens.screens

        ScreenState {}
    }

    Variants {
        id: components

        model: Screens.screens

        Components {}
    }

    Connections {
        function onModelChanged(change: var): void {
            // Keep the per-output layout in step with additions, removals,
            // rotations and scale changes. Offline entries are retained.
            PanelLayout.reconcile(Screens.screens);
        }

        target: Screens
    }

    component Components: QtObject {
        required property ShellScreen modelData

        property var background
        property var rootWindow
        property var interactionWrapper
        property var bar
        property var panels

        function find(name: string, rootItem: Item): var {
            return CUtils.findChild(rootItem ?? rootWindow?.contentItem, name);
        }

        function findAll(name: string, rootItem: Item): var {
            return CUtils.findChildren(rootItem ?? rootWindow?.contentItem, name);
        }

        function findMatching(pattern: string, rootItem: Item): var {
            return CUtils.findChildrenMatching(rootItem ?? rootWindow?.contentItem, pattern);
        }
    }

    component ComponentRef: QtObject {
        required property ShellScreen screen
        required property string slot
        required property var component

        // Capture the object that actually received the reference.  During
        // output teardown `screen` may already be invalid, so destruction must
        // not look it up again through the screen object.
        property QtObject boundTarget: null
        readonly property QtObject target: ShellState.componentsFor(screen)

        onTargetChanged: {
            if (!target)
                return;
            boundTarget = target;
            target[slot] = component;
        }

        Component.onDestruction: {
            const target = boundTarget;
            boundTarget = null;
            if (target && target[slot] === component)
                target[slot] = null;
        }
    }
}
