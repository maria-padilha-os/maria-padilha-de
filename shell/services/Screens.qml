pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import "ScreenModel.js" as ScreenModel

Singleton {
    id: root

    // Quickshell gives us the current outputs; this model makes the list safe
    // for QML: disabled outputs are filtered, duplicate connector entries are
    // collapsed, and an output is never identified by its index in the array.
    readonly property list<ShellScreen> screens: ScreenModel.selectScreens(Quickshell.screens, screen => GlobalConfig.forScreen(screen.name).enabled)
    readonly property var snapshot: ScreenModel.snapshot(screens)
    readonly property string focusedName: Hyprland.focusedMonitor?.name ?? ""
    readonly property ShellScreen primary: ScreenModel.choosePrimary(screens, {
        focusedName: root.focusedName
    })
    readonly property ShellScreen focused: root.byName(root.focusedName) ?? root.primary
    readonly property string focusedKey: root.focused ? root.keyFor(root.focused) : ""
    readonly property string primaryName: root.primary ? root.keyFor(root.primary) : ""
    readonly property var names: root.screens.map(screen => screen.name)
    readonly property var keys: root.screens.map(screen => root.keyFor(screen))

    // Consumers that only need to know "did the output set, geometry, rotation
    // or scale change?" can watch this without comparing lists themselves.
    property int revision
    property var lastSnapshot: []

    signal modelChanged(var change)

    function byName(name: string): ShellScreen {
        return ScreenModel.byName(root.screens, name);
    }

    function keyFor(screen: ShellScreen): string {
        return ScreenModel.keyFor(screen, root.screens.indexOf(screen));
    }

    function describe(screen: ShellScreen): var {
        return ScreenModel.describe(screen, root.screens.indexOf(screen));
    }

    function isPrimary(screen: ShellScreen): bool {
        return !!screen && !!root.primary && root.keyFor(screen) === root.keyFor(root.primary);
    }

    function isExcluded(screen: ShellScreen): bool {
        if (!screen)
            return true;
        return !GlobalConfig.forScreen(screen.name).enabled;
    }

    function current(screen: ShellScreen): ShellScreen {
        if (!screen)
            return null;
        return root.byName(screen.name);
    }

    onSnapshotChanged: {
        const change = ScreenModel.diff(root.lastSnapshot, root.snapshot);
        root.lastSnapshot = root.snapshot;
        if (!change.touched)
            return;
        root.revision++;
        root.modelChanged(change);
    }
}
