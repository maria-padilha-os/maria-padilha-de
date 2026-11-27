pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.assistant as AssistantPanel

Variants {
    model: Screens.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        Exclusions {
            screen: scope.modelData
            bar: content.bar
        }

        ContentWindow {
            id: content

            screen: scope.modelData
        }

        AssistantPanel.Handle {
            screen: scope.modelData
            screenState: ShellState.forScreen(scope.modelData)
        }
    }
}
