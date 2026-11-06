pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Caelestia.Config
import Caelestia.I18n

// Fully offline unit conversion. Nothing is loaded from disk or the network;
// the factors below are the conversion table.
Item {
    id: root

    property var api
    property bool active: true
    property bool compact: false

    property int categoryIndex: 0
    property int fromIndex: 0
    property int toIndex: 1
    property string amount: "1"

    readonly property var palette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color foreground: root.palette ? root.palette.m3onSurface : "transparent"
    readonly property color muted: root.palette ? root.palette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.palette ? root.palette.m3primary : "transparent"
    readonly property color onAccent: root.palette ? root.palette.m3onPrimary : "transparent"
    readonly property color fieldColour: root.palette ? root.palette.m3surfaceContainerHigh : "transparent"
    readonly property color outline: root.palette ? root.palette.m3outlineVariant : "transparent"

    readonly property var categories: [
        {
            id: "length",
            name: Tr.tr("Length"),
            units: [
                {
                    name: Tr.tr("Millimetres"),
                    symbol: "mm",
                    factor: 0.001
                },
                {
                    name: Tr.tr("Centimetres"),
                    symbol: "cm",
                    factor: 0.01
                },
                {
                    name: Tr.tr("Metres"),
                    symbol: "m",
                    factor: 1
                },
                {
                    name: Tr.tr("Kilometres"),
                    symbol: "km",
                    factor: 1000
                },
                {
                    name: Tr.tr("Inches"),
                    symbol: "in",
                    factor: 0.0254
                },
                {
                    name: Tr.tr("Feet"),
                    symbol: "ft",
                    factor: 0.3048
                },
                {
                    name: Tr.tr("Yards"),
                    symbol: "yd",
                    factor: 0.9144
                },
                {
                    name: Tr.tr("Miles"),
                    symbol: "mi",
                    factor: 1609.344
                },
                {
                    name: Tr.tr("Nautical miles"),
                    symbol: "nmi",
                    factor: 1852
                }
            ]
        },
        {
            id: "mass",
            name: Tr.tr("Mass"),
            units: [
                {
                    name: Tr.tr("Milligrams"),
                    symbol: "mg",
                    factor: 0.000001
                },
                {
                    name: Tr.tr("Grams"),
                    symbol: "g",
                    factor: 0.001
                },
                {
                    name: Tr.tr("Kilograms"),
                    symbol: "kg",
                    factor: 1
                },
                {
                    name: Tr.tr("Tonnes"),
                    symbol: "t",
                    factor: 1000
                },
                {
                    name: Tr.tr("Ounces"),
                    symbol: "oz",
                    factor: 0.028349523125
                },
                {
                    name: Tr.tr("Pounds"),
                    symbol: "lb",
                    factor: 0.45359237
                },
                {
                    name: Tr.tr("Stones"),
                    symbol: "st",
                    factor: 6.35029318
                }
            ]
        },
        {
            id: "temperature",
            name: Tr.tr("Temperature"),
            units: [
                {
                    name: Tr.tr("Celsius"),
                    symbol: "°C",
                    factor: 1
                },
                {
                    name: Tr.tr("Fahrenheit"),
                    symbol: "°F",
                    factor: 1
                },
                {
                    name: Tr.tr("Kelvin"),
                    symbol: "K",
                    factor: 1
                }
            ]
        },
        {
            id: "data",
            name: Tr.tr("Data"),
            units: [
                {
                    name: Tr.tr("Bytes"),
                    symbol: "B",
                    factor: 1
                },
                {
                    name: Tr.tr("Kilobytes"),
                    symbol: "kB",
                    factor: 1000
                },
                {
                    name: Tr.tr("Megabytes"),
                    symbol: "MB",
                    factor: 1000000
                },
                {
                    name: Tr.tr("Gigabytes"),
                    symbol: "GB",
                    factor: 1000000000
                },
                {
                    name: Tr.tr("Terabytes"),
                    symbol: "TB",
                    factor: 1000000000000
                },
                {
                    name: Tr.tr("Kibibytes"),
                    symbol: "KiB",
                    factor: 1024
                },
                {
                    name: Tr.tr("Mebibytes"),
                    symbol: "MiB",
                    factor: 1048576
                },
                {
                    name: Tr.tr("Gibibytes"),
                    symbol: "GiB",
                    factor: 1073741824
                },
                {
                    name: Tr.tr("Tebibytes"),
                    symbol: "TiB",
                    factor: 1099511627776
                }
            ]
        },
        {
            id: "time",
            name: Tr.tr("Time"),
            units: [
                {
                    name: Tr.tr("Nanoseconds"),
                    symbol: "ns",
                    factor: 0.000000001
                },
                {
                    name: Tr.tr("Microseconds"),
                    symbol: "µs",
                    factor: 0.000001
                },
                {
                    name: Tr.tr("Milliseconds"),
                    symbol: "ms",
                    factor: 0.001
                },
                {
                    name: Tr.tr("Seconds"),
                    symbol: "s",
                    factor: 1
                },
                {
                    name: Tr.tr("Minutes"),
                    symbol: "min",
                    factor: 60
                },
                {
                    name: Tr.tr("Hours"),
                    symbol: "h",
                    factor: 3600
                },
                {
                    name: Tr.tr("Days"),
                    symbol: "d",
                    factor: 86400
                },
                {
                    name: Tr.tr("Weeks"),
                    symbol: "wk",
                    factor: 604800
                }
            ]
        }
    ]

    readonly property var category: root.categories[root.categoryIndex] ?? root.categories[0]
    readonly property var units: root.category.units
    readonly property var fromUnit: root.units[root.fromIndex] ?? root.units[0]
    readonly property var toUnit: root.units[root.toIndex] ?? root.units[0]
    readonly property var inputValue: {
        const text = root.amount.trim().replace(",", ".");
        return text.length === 0 ? NaN : Number(text);
    }
    readonly property var converted: root.convert(root.inputValue)
    readonly property string output: Number.isFinite(root.converted) ? root.formatNumber(root.converted) : ""

    function toBase(value: real, unit: var): real {
        if (root.category.id === "temperature") {
            if (unit.symbol === "°F")
                return (value - 32) * 5 / 9;
            if (unit.symbol === "K")
                return value - 273.15;
            return value;
        }
        return value * unit.factor;
    }

    function fromBase(value: real, unit: var): real {
        if (root.category.id === "temperature") {
            if (unit.symbol === "°F")
                return value * 9 / 5 + 32;
            if (unit.symbol === "K")
                return value + 273.15;
            return value;
        }
        return value / unit.factor;
    }

    function convert(value: var): var {
        if (!Number.isFinite(value) || !root.fromUnit || !root.toUnit)
            return NaN;
        return root.fromBase(root.toBase(value, root.fromUnit), root.toUnit);
    }

    function formatNumber(value: real): string {
        if (!Number.isFinite(value))
            return "";
        if (value === 0)
            return "0";
        const rounded = Number(value.toPrecision(12));
        if (Math.abs(rounded) >= 1e12 || Math.abs(rounded) < 1e-6)
            return rounded.toExponential(6).replace(/\.?0+e/, "e");
        return String(rounded);
    }

    function selectCategory(index: int): void {
        root.categoryIndex = index;
        root.fromIndex = 0;
        root.toIndex = Math.min(1, root.categories[index].units.length - 1);
    }

    function swap(): void {
        const converted = root.output;
        const oldFrom = root.fromIndex;
        root.fromIndex = root.toIndex;
        root.toIndex = oldFrom;
        if (converted.length > 0 && Number.isFinite(Number(converted))) {
            root.amount = converted;
            amountField.text = converted;
        }
    }

    component CategoryButton: Rectangle {
        id: button

        property string label
        property bool selected
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 30
        radius: Tokens.rounding.small
        color: button.selected ? root.accent : (buttonMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent")
        border.width: button.selected ? 0 : 1
        border.color: root.outline

        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.selected ? root.onAccent : root.foreground
            font: Tokens.font.label.medium
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component UnitPicker: Item {
        id: picker

        property var options: []
        property int selectedIndex: 0
        property bool expanded: false
        signal picked(int index)

        implicitHeight: 36

        Rectangle {
            id: pickerField

            anchors.fill: parent
            radius: Tokens.rounding.small
            color: root.fieldColour
            border.width: 1
            border.color: picker.expanded ? root.accent : root.outline

            Text {
                anchors.left: parent.left
                anchors.right: pickerArrow.left
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.small
                anchors.verticalCenter: parent.verticalCenter
                text: picker.options[picker.selectedIndex]?.name ?? ""
                color: root.foreground
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            Text {
                id: pickerArrow

                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.medium
                anchors.verticalCenter: parent.verticalCenter
                text: "▾"
                color: root.muted
                font: Tokens.font.label.medium
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: picker.expanded = !picker.expanded
            }
        }

        Rectangle {
            id: pickerMenu

            anchors.top: pickerField.bottom
            anchors.topMargin: 2
            width: pickerField.width
            height: Math.min(190, picker.options.length * 30 + 4)
            visible: picker.expanded
            z: 20
            radius: Tokens.rounding.small
            color: root.fieldColour
            border.width: 1
            border.color: root.outline
            clip: true

            ListView {
                anchors.fill: parent
                anchors.margins: 2
                clip: true
                model: picker.options

                delegate: Rectangle {
                    id: optionRow

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 28
                    radius: Tokens.rounding.small
                    color: picker.selectedIndex === optionRow.index ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : (optionMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Tokens.padding.small
                        anchors.rightMargin: Tokens.padding.small
                        anchors.verticalCenter: parent.verticalCenter
                        text: optionRow.modelData.name
                        color: root.foreground
                        font: Tokens.font.label.medium
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: optionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            picker.expanded = false;
                            picker.picked(optionRow.index);
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? Tokens.padding.medium : Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: root.categories

                delegate: CategoryButton {
                    required property var modelData
                    required property int index

                    label: modelData.name
                    selected: root.categoryIndex === index
                    onClicked: root.selectCategory(index)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            TextField {
                id: amountField

                Layout.preferredWidth: 140
                Layout.minimumWidth: 80
                placeholderText: "1"
                color: root.foreground
                placeholderTextColor: root.muted
                font: Tokens.font.body.large
                selectByMouse: true
                background: Rectangle {
                    radius: Tokens.rounding.small
                    color: root.fieldColour
                    border.width: 1
                    border.color: amountField.activeFocus ? root.accent : root.outline
                }

                Component.onCompleted: text = root.amount

                onTextChanged: root.amount = text
                onAccepted: root.amount = text
            }

            UnitPicker {
                Layout.fillWidth: true
                options: root.units
                selectedIndex: root.fromIndex
                onPicked: index => root.fromIndex = index
            }

            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: Tokens.rounding.full
                color: swapMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent"
                border.width: 1
                border.color: root.outline

                Text {
                    anchors.centerIn: parent
                    text: "⇄"
                    color: root.accent
                    font: Tokens.font.body.medium
                }

                MouseArea {
                    id: swapMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.swap()
                }
            }

            UnitPicker {
                Layout.fillWidth: true
                options: root.units
                selectedIndex: root.toIndex
                onPicked: index => root.toIndex = index
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.medium
            color: root.fieldColour
            border.width: 1
            border.color: root.outline

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - Tokens.padding.large * 2
                spacing: Tokens.spacing.extraSmall

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.output.length > 0 ? root.output : "—"
                    color: root.output.length > 0 ? root.foreground : root.muted
                    font: Tokens.font.title.large
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: `${root.fromUnit?.symbol ?? ""} → ${root.toUnit?.symbol ?? ""}`
                    color: root.muted
                    font: Tokens.font.label.medium
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Tr.tr("Offline conversion, no accounts or network")
                    color: root.muted
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }
        }
    }
}
