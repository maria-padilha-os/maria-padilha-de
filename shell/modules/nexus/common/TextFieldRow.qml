pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

ConnectedRect {
    id: root

    property alias label: label.text
    property string subtext
    property string value
    property alias placeholderText: input.placeholderText
    property string errorText
    property alias maximumLength: input.maximumLength
    property alias validate: input.validate
    property alias validator: input.validator
    property alias echoMode: input.echoMode
    property bool smallField
    readonly property alias field: input
    readonly property bool settingsRow: true
    readonly property bool settingsInteractive: true
    readonly property string settingsLabel: root.label
    readonly property string settingsDescription: root.subtext
    readonly property bool invalid: input.isError || (input.text.length > 0 && !input.valid) || (!input.emptyIsValid && input.text.length === 0)

    signal valueEdited(value: string)
    signal editingFinished(value: string)

    function clear(): void {
        input.clear();
    }

    function commit(): bool {
        input.isError = !input.valid;
        if (input.isError) {
            input.forceActiveFocus();
            return false;
        }
        if (value !== input.text)
            editingFinished(input.text);
        return true;
    }

    Component.onDestruction: {
        // A page jump destroys the row. Flush a valid pending edit instead of
        // dropping it with the component; an invalid edit stays visibly
        // invalid if the page survives and must not mutate the config.
        if (input.valid && value !== input.text)
            editingInput(input.text);
    }

    function editingInput(text: string): void {
        root.editingFinished(text);
    }

    Layout.fillWidth: true
    activeFocusOnTab: true
    Accessible.role: Accessible.EditableText
    Accessible.name: root.label
    Accessible.description: root.invalid && root.errorText ? root.errorText : root.subtext
    Accessible.focusable: root.enabled
    Accessible.focused: root.activeFocus
    Accessible.onPressAction: input.forceActiveFocus()

    Keys.onReturnPressed: {
        input.forceActiveFocus();
        input.selectAll();
    }
    Keys.onEnterPressed: {
        input.forceActiveFocus();
        input.selectAll();
    }

    FocusRing {
        target: root
        colour: Colours.palette.m3primary
        radius: Tokens.rounding.small
        margin: 2
    }
    implicitHeight: rowLayout.implicitHeight + Tokens.padding.medium + Math.max(0, Tokens.padding.large - input.verticalPadding) * 2

    RowLayout {
        id: rowLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: label

                Layout.fillWidth: true
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.invalid && root.errorText ? root.errorText.length > 0 : root.subtext.length > 0
                text: root.invalid && root.errorText ? root.errorText : root.subtext
                color: root.invalid && root.errorText ? Colours.palette.m3error : Colours.palette.m3outline
                font: Tokens.font.label.small
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                animate: root.errorText
            }
        }

        StyledTextField {
            id: input

            Layout.preferredWidth: root.smallField ? Tokens.sizes.nexus.smallTextFieldWidth : Tokens.sizes.nexus.textFieldWidth
            Layout.maximumWidth: root.width / 2
            Layout.alignment: Qt.AlignVCenter
            verticalPadding: Tokens.padding.small
            activeFocusOnTab: true

            text: root.value

            onTextEdited: root.valueEdited(text)
            onEditingFinished: root.editingFinished(text)
        }
    }
}
