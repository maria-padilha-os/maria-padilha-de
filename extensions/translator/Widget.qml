import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// Translation UI shared by the settings Page and the dashboard Tab.
// `api` is assigned by the host; theme colours always come from the Colours
// singleton through it. Nothing here runs until the user asks for a
// translation (the Tab also sets `compact`).
Item {
    id: root

    property var api
    property bool compact: false
    property bool active: true

    // Kept in sync with Tab.qml so the dashboard never gives this panel less
    // room than its two text areas and the language row can share.
    readonly property int minimumWidth: 360
    readonly property int minimumHeight: 260
    readonly property int edgePadding: root.compact ? Tokens.padding.medium : Tokens.padding.extraLarge
    readonly property int controlHeight: Math.max(Tokens.font.label.medium.pointSize + Tokens.padding.medium * 2, Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall)
    readonly property int menuHeight: root.compact ? Tokens.sizes.dashboard.perfBattHeight : Tokens.sizes.dashboard.perfNetworkCardHeight

    readonly property var themePalette: root.api && root.api.colours ? root.api.colours.palette : null

    // Keep transparent fallbacks so bindings survive the moment before the host
    // assigns `api`; once it is set these become real palette colours.
    readonly property color foreground: root.themePalette ? root.themePalette.m3onSurface : "transparent"
    readonly property color muted: root.themePalette ? root.themePalette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.themePalette ? root.themePalette.m3primary : "transparent"
    readonly property color onAccent: root.themePalette ? root.themePalette.m3onPrimary : "transparent"
    readonly property color surface: root.themePalette ? root.themePalette.m3surfaceContainerHigh : "transparent"
    readonly property color outline: root.themePalette ? root.themePalette.m3outline : "transparent"
    readonly property color danger: root.themePalette ? root.themePalette.m3error : "transparent"

    // MyMemory codes; labels stay in English like the manifest.
    readonly property var languages: [
        {
            "name": "English",
            "code": "en"
        },
        {
            "name": "Portuguese",
            "code": "pt-BR"
        },
        {
            "name": "Spanish",
            "code": "es"
        },
        {
            "name": "French",
            "code": "fr"
        },
        {
            "name": "German",
            "code": "de"
        },
        {
            "name": "Italian",
            "code": "it"
        },
        {
            "name": "Japanese",
            "code": "ja"
        },
        {
            "name": "Russian",
            "code": "ru"
        },
        {
            "name": "Chinese (Simplified)",
            "code": "zh-CN"
        }
    ]

    property bool busy: false
    property bool statusIsError: false
    property string status: ""
    property string pendingFromName: ""
    property string pendingToName: ""

    // Exposed for tests and for the compact tab to prefill text.
    property alias sourceText: sourcePanel.text
    property alias resultText: resultPanel.text

    Component.onCompleted: {
        sourcePanel.focusEditor();
        if (root.active)
            root.pasteFromClipboard();
    }

    onActiveChanged: {
        if (root.active)
            root.pasteFromClipboard();
    }

    function pasteFromClipboard(): void {
        if (root.busy || root.sourceText.trim().length > 0)
            return;
        pasteProc.running = true;
    }

    function copyResult() {
        if (root.resultText.length === 0)
            return;
        copyProc.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", root.resultText];
        copyProc.running = true;
    }

    function setStatus(message, isError) {
        root.status = message;
        root.statusIsError = isError;
    }

    function languageCode(combo) {
        var language = root.languages[combo.selectedIndex];
        return language ? language.code : "";
    }

    function languageName(combo) {
        var language = root.languages[combo.selectedIndex];
        return language ? language.name : "";
    }

    function translate() {
        if (root.busy)
            return;

        var text = sourcePanel.text;
        if (text.trim().length === 0) {
            root.setStatus(Tr.tr("Enter some text to translate."), true);
            sourcePanel.focusEditor();
            return;
        }
        if (text.length > 500) {
            root.setStatus(Tr.tr("MyMemory accepts up to 500 characters per request."), true);
            return;
        }
        if (fromPicker.selectedIndex === toPicker.selectedIndex) {
            root.setStatus(Tr.tr("Choose two different languages."), true);
            return;
        }

        fromPicker.collapse();
        toPicker.collapse();

        var fromCode = root.languageCode(fromPicker);
        var toCode = root.languageCode(toPicker);
        var fromName = root.languageName(fromPicker);
        var toName = root.languageName(toPicker);

        root.busy = true;
        resultPanel.text = "";
        root.setStatus(Tr.tr("Translating…"), false);

        root.pendingFromName = fromName;
        root.pendingToName = toName;

        var url = "https://api.mymemory.translated.net/get?q=" + encodeURIComponent(text) + "&langpair=" + encodeURIComponent(fromCode) + "%7C" + encodeURIComponent(toCode);
        translateProc.command = ["curl", "-fsSL", "--max-time", "20", url];
        translateProc.running = true;
    }

    function finishTranslation(exitCode, output, errorText) {
        if (!root.busy)
            return;
        root.busy = false;

        if (exitCode !== 0) {
            var detail = errorText.trim();
            root.setStatus(detail.length > 0 ? detail : Tr.tr("Network error: could not reach MyMemory."), true);
            return;
        }

        var data = null;
        try {
            data = JSON.parse(output);
        } catch (error) {
            data = null;
        }
        if (!data || typeof data !== "object") {
            root.setStatus(Tr.tr("The service returned an invalid response."), true);
            return;
        }

        var apiStatus = data.responseStatus === undefined || data.responseStatus === null ? 0 : Number(data.responseStatus);
        var details = data.responseDetails ? String(data.responseDetails) : "";
        var translated = data.responseData && data.responseData.translatedText ? String(data.responseData.translatedText) : "";

        if (apiStatus !== 200) {
            if (details.length > 0)
                root.setStatus(details, true);
            else if (translated.length > 0)
                root.setStatus(translated, true);
            else
                root.setStatus(Tr.tr("Translation failed."), true);
            return;
        }
        if (translated.length === 0) {
            root.setStatus(Tr.tr("The service returned an empty translation."), true);
            return;
        }
        if (translated.indexOf("MYMEMORY WARNING") !== -1 || translated.indexOf("QUERY LENGTH LIMIT") !== -1) {
            // Quota and length problems come back as a 200 with the warning
            // in translatedText instead of a proper error status.
            root.setStatus(translated, true);
            return;
        }

        resultPanel.text = translated;
        resultPanel.scrollToTop();
        root.setStatus(Tr.tr("Translated from %1 to %2.").arg(root.pendingFromName).arg(root.pendingToName), false);
    }

    function swap() {
        if (root.busy)
            return;

        fromPicker.collapse();
        toPicker.collapse();

        var oldFrom = fromPicker.selectedIndex;
        fromPicker.selectedIndex = toPicker.selectedIndex;
        toPicker.selectedIndex = oldFrom;

        var translated = resultPanel.text;
        if (translated.length > 0) {
            resultPanel.text = sourcePanel.text;
            sourcePanel.text = translated;
            root.setStatus(Tr.tr("Languages and text swapped."), false);
        } else {
            root.setStatus(Tr.tr("Languages swapped."), false);
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(Math.max(root.minimumWidth, parent.width - root.edgePadding * 2), 760)
        height: Math.min(Math.max(root.minimumHeight, parent.height - root.edgePadding * 2), 620)
        spacing: root.compact ? Tokens.spacing.extraSmall : Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            // Keep the overflowing dropdowns above the text panels below.
            z: 1
            spacing: Tokens.spacing.small

            LanguagePicker {
                id: fromPicker

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                enabled: !root.busy
                options: root.languages
                menuMaxHeight: root.menuHeight
                foreground: root.foreground
                mutedColour: root.muted
                fieldColour: root.surface
                menuColour: root.surface
                borderColour: root.outline
                accentColour: root.accent
                onExpandedChanged: {
                    if (expanded)
                        toPicker.collapse();
                }
            }

            Rectangle {
                id: swapButton

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: root.controlHeight
                Layout.preferredHeight: root.controlHeight
                radius: Tokens.rounding.full
                color: swapMouse.containsMouse ? root.surface : "transparent"
                border.width: swapButton.activeFocus ? 2 : 1
                border.color: swapButton.activeFocus ? root.accent : root.outline
                opacity: root.busy ? 0.4 : 1
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: Tr.tr("Swap languages")

                Keys.onReturnPressed: root.swap()
                Keys.onSpacePressed: root.swap()

                Text {
                    anchors.centerIn: parent
                    text: "⇄"
                    color: root.accent
                    font: Tokens.font.body.large
                }

                MouseArea {
                    id: swapMouse

                    anchors.fill: parent
                    enabled: !root.busy
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        swapButton.forceActiveFocus();
                        root.swap();
                    }
                }
            }

            LanguagePicker {
                id: toPicker

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                enabled: !root.busy
                options: root.languages
                selectedIndex: 1
                menuMaxHeight: root.menuHeight
                foreground: root.foreground
                mutedColour: root.muted
                fieldColour: root.surface
                menuColour: root.surface
                borderColour: root.outline
                accentColour: root.accent
                onExpandedChanged: {
                    if (expanded)
                        fromPicker.collapse();
                }
            }
        }

        TextPanel {
            id: sourcePanel

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: root.compact ? 48 : 150
            compact: root.compact
            foreground: root.foreground
            mutedColour: root.muted
            surfaceColour: root.surface
            outlineColour: root.outline
            accentColour: root.accent
            accentTextColour: root.onAccent
            placeholderText: Tr.tr("Type text to translate…")
            onSubmit: root.translate()
        }

        TextPanel {
            id: resultPanel

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: root.compact ? 48 : 150
            compact: root.compact
            readOnly: true
            foreground: root.foreground
            mutedColour: root.muted
            surfaceColour: root.surface
            outlineColour: root.outline
            accentColour: root.accent
            accentTextColour: root.onAccent
            placeholderText: Tr.tr("Translation")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.status.length > 0 ? root.status : Tr.tr("Ctrl+Enter to translate")
                color: root.statusIsError ? root.danger : root.muted
                font: Tokens.font.body.small
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                visible: root.sourceText.length > 0
                text: root.sourceText.length + " / 500"
                color: root.sourceText.length > 500 ? root.danger : root.muted
                font: Tokens.font.label.small
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                id: copyButton

                visible: root.resultText.length > 0
                Layout.preferredHeight: root.controlHeight
                implicitWidth: copyLabel.implicitWidth + Tokens.padding.large * 2
                radius: Tokens.rounding.full
                color: copyMouse.containsMouse ? root.surface : "transparent"
                border.width: copyButton.activeFocus ? 2 : 1
                border.color: copyButton.activeFocus ? root.accent : root.outline
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: Tr.tr("Copy translation")

                Keys.onReturnPressed: root.copyResult()
                Keys.onSpacePressed: root.copyResult()

                Text {
                    id: copyLabel

                    anchors.centerIn: parent
                    text: Tr.tr("Copy")
                    color: root.foreground
                    font: Tokens.font.label.medium
                    elide: Text.ElideRight
                    width: Math.max(0, parent.width - Tokens.padding.small * 2)
                    horizontalAlignment: Text.AlignHCenter
                }

                MouseArea {
                    id: copyMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        copyButton.forceActiveFocus();
                        root.copyResult();
                    }
                }
            }

            Rectangle {
                id: translateButton

                Layout.preferredHeight: root.controlHeight
                implicitWidth: translateLabel.implicitWidth + Tokens.padding.large * 2
                radius: Tokens.rounding.full
                color: !root.busy && translateMouse.containsMouse ? Qt.alpha(root.accent, 0.9) : root.accent
                border.width: translateButton.activeFocus ? 2 : 0
                border.color: root.onAccent
                opacity: root.busy ? 0.55 : 1
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: Tr.tr("Translate")

                Keys.onReturnPressed: root.translate()
                Keys.onSpacePressed: root.translate()

                Text {
                    id: translateLabel

                    anchors.centerIn: parent
                    text: root.busy ? Tr.tr("Translating…") : Tr.tr("Translate")
                    color: root.onAccent
                    font: Tokens.font.label.medium
                    elide: Text.ElideRight
                    width: Math.max(0, parent.width - Tokens.padding.small * 2)
                    horizontalAlignment: Text.AlignHCenter
                }

                MouseArea {
                    id: translateMouse

                    anchors.fill: parent
                    enabled: !root.busy
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        translateButton.forceActiveFocus();
                        root.translate();
                    }
                }
            }
        }
    }

    Process {
        id: copyProc

        onExited: root.setStatus(Tr.tr("Copied to clipboard."), false)
    }

    // When the tab is opened (for example with Super+Alt+T) and the source is
    // still empty, take the clipboard text. 500 characters is MyMemory's cap.
    Process {
        id: pasteProc

        command: ["timeout", "2", "wl-paste", "--no-newline"]
        stdout: StdioCollector {
            id: pasteOut
        }
        stderr: StdioCollector {
            id: pasteErr
        }

        onExited: (exitCode) => {
            if (exitCode !== 0 || root.sourceText.trim().length > 0)
                return;

            let text = pasteOut.text.replace(/\r?\n$/, "");
            if (text.trim().length === 0)
                return;

            if (text.length > 500) {
                text = text.slice(0, 500);
                root.setStatus(Tr.tr("Pasted from the clipboard (truncated to 500 characters)."), false);
            } else {
                root.setStatus(Tr.tr("Pasted from the clipboard."), false);
            }
            root.sourceText = text;
            sourcePanel.focusEditor();
        }
    }

    Process {
        id: translateProc

        stdout: StdioCollector {
            id: translateOut
        }
        stderr: StdioCollector {
            id: translateErr
        }

        onExited: (exitCode) => root.finishTranslation(exitCode, translateOut.text, translateErr.text)
    }

    // Editable/read-only text box with a palette-coloured border and a thin
    // scrollbar. Ctrl+Enter is forwarded so both panels can trigger a request.
    component TextPanel: Rectangle {
        id: panel

        property alias text: area.text
        property alias readOnly: area.readOnly
        property alias placeholderText: area.placeholderText
        property color foreground: "transparent"
        property color mutedColour: "transparent"
        property color surfaceColour: "transparent"
        property color outlineColour: "transparent"
        property color accentColour: "transparent"
        property color accentTextColour: "transparent"
        property bool compact: false

        signal submit()

        radius: Tokens.rounding.medium
        color: panel.surfaceColour
        border.width: area.activeFocus ? 2 : 1
        border.color: area.activeFocus ? panel.accentColour : panel.outlineColour

        function focusEditor() {
            area.forceActiveFocus();
        }

        function scrollToTop() {
            scroll.contentItem.contentY = 0;
        }

        ScrollView {
            id: scroll

            anchors.fill: parent
            anchors.margins: 1
            clip: true

            ScrollBar.vertical: ScrollBar {
                id: verticalBar

                policy: ScrollBar.AsNeeded
                width: Tokens.padding.small
                background: Rectangle {
                    color: "transparent"
                }
                contentItem: Rectangle {
                    implicitWidth: Tokens.padding.extraSmall
                    implicitHeight: Tokens.padding.extraExtraLarge / 2
                    radius: width / 2
                    color: verticalBar.pressed ? panel.accentColour : panel.outlineColour
                }
            }

            TextArea {
                id: area

                width: scroll.availableWidth
                height: Math.max(implicitHeight, scroll.availableHeight)
                font: Tokens.font.body.small
                color: panel.foreground
                placeholderTextColor: panel.mutedColour
                selectionColor: panel.accentColour
                selectedTextColor: panel.accentTextColour
                wrapMode: TextArea.Wrap
                selectByMouse: true
                persistentSelection: true
                textFormat: TextEdit.PlainText
                leftPadding: Tokens.padding.medium
                rightPadding: Tokens.padding.large
                topPadding: Tokens.padding.small
                bottomPadding: Tokens.padding.small
                background: null

                Keys.onPressed: function (event) {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                        event.accepted = true;
                        panel.submit();
                    }
                }
            }
        }
    }

    // Palette-styled dropdown. The list is an inline overlay instead of a
    // QML Popup window so it stays inside the layer-shell surface.
    component LanguagePicker: Rectangle {
        id: picker

        property var options: []
        property int selectedIndex: 0
        property bool expanded: false
        property int menuMaxHeight: 220
        property color foreground: "transparent"
        property color mutedColour: "transparent"
        property color fieldColour: "transparent"
        property color menuColour: "transparent"
        property color borderColour: "transparent"
        property color accentColour: "transparent"

        implicitHeight: Tokens.font.body.small.pointSize + Tokens.padding.medium * 2
        radius: Tokens.rounding.small
        color: picker.fieldColour
        border.width: picker.activeFocus ? 2 : 1
        border.color: picker.activeFocus || picker.expanded || pickerMouse.containsMouse ? picker.accentColour : picker.borderColour
        opacity: picker.enabled ? 1 : 0.5
        activeFocusOnTab: true

        Accessible.role: Accessible.ComboBox
        Accessible.name: picker.selectedIndex >= 0 && picker.selectedIndex < picker.options.length ? picker.options[picker.selectedIndex].name : ""

        Keys.onReturnPressed: picker.expanded = !picker.expanded
        Keys.onSpacePressed: picker.expanded = !picker.expanded
        Keys.onEscapePressed: picker.expanded = false

        function collapse() {
            picker.expanded = false;
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.medium
            anchors.right: arrow.left
            anchors.rightMargin: Tokens.spacing.extraSmall
            anchors.verticalCenter: parent.verticalCenter
            text: picker.selectedIndex >= 0 && picker.selectedIndex < picker.options.length ? picker.options[picker.selectedIndex].name : ""
            color: picker.foreground
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }

        Text {
            id: arrow

            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.small
            anchors.verticalCenter: parent.verticalCenter
            text: "▾"
            color: picker.mutedColour
            font: Tokens.font.body.small
        }

        MouseArea {
            id: pickerMouse

            anchors.fill: parent
            enabled: picker.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                picker.forceActiveFocus();
                picker.expanded = !picker.expanded;
            }
        }

        Rectangle {
            id: menu

            visible: picker.expanded
            z: 10
            y: picker.height + Tokens.spacing.extraSmall
            width: picker.width
            height: Math.min(menuList.contentHeight + 2 * Tokens.padding.extraSmall, picker.menuMaxHeight)
            radius: Tokens.rounding.small
            color: picker.menuColour
            border.width: 1
            border.color: picker.borderColour

            ListView {
                id: menuList

                anchors.fill: parent
                anchors.margins: Tokens.padding.extraSmall
                clip: true
                model: picker.options
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    id: menuBar

                    policy: ScrollBar.AsNeeded
                    width: Tokens.padding.extraSmall + Tokens.padding.extraSmall / 2
                    background: Rectangle {
                        color: "transparent"
                    }
                    contentItem: Rectangle {
                        implicitWidth: Tokens.padding.extraSmall - 1
                        implicitHeight: Tokens.padding.largeIncreased
                        radius: width / 2
                        color: menuBar.pressed ? picker.accentColour : picker.borderColour
                    }
                }

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index

                    width: menuList.width
                    height: Tokens.font.body.small.pointSize + Tokens.padding.small * 2

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.rounding.extraSmall
                        color: rowMouse.containsMouse || picker.selectedIndex === row.index ? Qt.alpha(picker.accentColour, 0.16) : "transparent"
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Tokens.padding.small
                        anchors.rightMargin: Tokens.padding.medium
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: picker.selectedIndex === row.index ? picker.accentColour : picker.foreground
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            picker.selectedIndex = row.index;
                            picker.expanded = false;
                        }
                    }
                }
            }
        }
    }
}
