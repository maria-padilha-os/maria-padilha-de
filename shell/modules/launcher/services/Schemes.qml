pragma Singleton

import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

Searcher {
    id: root

    property string currentScheme
    property string currentVariant

    function transformSearch(search: string): string {
        return search.slice(`${GlobalConfig.launcher.actionPrefix}scheme `.length);
    }

    function selector(item: var): string {
        return item.name;
    }

    function reload(): void {
        getCurrent.running = true;
    }

    list: schemes.instances
    useFuzzy: GlobalConfig.launcher.useFuzzy.schemes
    keys: ["name", "flavour"]
    weights: [0.9, 0.1]

    Variants {
        id: schemes

        Scheme {}
    }

    Process {
        id: getSchemes

        running: true
        command: ["padilha", "scheme", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const schemeData = JSON.parse(text);
                schemes.model = Object.entries(schemeData).map(([variant, v]) => ({
                                name: variant,
                                flavour: "",
                                colours: v.colours
                            })).sort((a, b) => a.name.localeCompare(b.name));
            }
        }
    }

    Process {
        id: getCurrent

        running: true
        command: ["padilha", "scheme", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const variant = text.trim();
                root.currentScheme = variant;
                root.currentVariant = variant;
            }
        }
    }

    component Scheme: QtObject {
        required property var modelData
        readonly property string name: modelData.name
        readonly property string flavour: modelData.flavour
        readonly property var colours: modelData.colours

        function onClicked(list: AppList): void {
            list.screenState.launcher = false;
            Quickshell.execDetached(["padilha", "scheme", "set", "--variant", name]);
        }
    }
}
