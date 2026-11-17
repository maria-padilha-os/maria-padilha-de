import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    // Temperature units (there must be one for each value of the TemperatureUnit enum)
    readonly property list<MenuItem> tempItems: [
        MenuItem {
            text: Tr.tr("Auto")
            value: TemperatureUnit.Auto
        },
        MenuItem {
            text: Tr.tr("°C")
            value: TemperatureUnit.Celsius
        },
        MenuItem {
            text: Tr.tr("°F")
            value: TemperatureUnit.Fahrenheit
        },
        MenuItem {
            text: Tr.tr("K")
            value: TemperatureUnit.Kelvin
        }
    ]

    // Data size units (there must be one for each value of the DataUnit enum)
    readonly property list<MenuItem> dataItems: [
        MenuItem {
            text: Tr.tr("Binary (KiB, MiB)")
            value: DataUnit.Binary
        },
        MenuItem {
            text: Tr.tr("Decimal (KB, MB)")
            value: DataUnit.Decimal
        }
    ]

    // Clock formats (there must be one for each value of the ClockFormat enum)
    readonly property list<MenuItem> clockItems: [
        MenuItem {
            text: Tr.tr("Auto")
            value: ClockFormat.Auto
        },
        MenuItem {
            text: Tr.tr("12-hour")
            value: ClockFormat.TwelveHour
        },
        MenuItem {
            text: Tr.tr("24-hour")
            value: ClockFormat.TwentyFourHour
        }
    ]

    function searchWeather(): void {
        Weather.searchLocations(weatherSearch.text);
    }

    title: Tr.tr("Language & region")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Language
        SectionHeader {
            first: true
            text: Tr.tr("Language")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("UI language")
            subtext: Tr.tr("The language used in the shell UI")
            active: menuItems.find(i => i.modelData === Tr.language) ?? autoLang
            onSelected: item => {
                Tr.language = item.modelData ?? ""; // qmllint disable missing-property
            }

            menuItems: [autoLang, ...langItems.instances]

            MenuItem {
                id: autoLang

                text: Tr.tr("Auto")
            }

            Variants {
                id: langItems

                model: Tr.supportedLanguages

                MenuItem {
                    required property string modelData

                    text: {
                        const locale = Qt.locale(modelData);
                        return locale.name === "C" ? modelData : locale.nativeLanguageName || locale.name;
                    }
                }
            }
        }

        // Weather
        SectionHeader {
            text: Tr.tr("Weather")
        }

        TextFieldRow {
            first: true
            label: Tr.tr("Saved location")
            subtext: Tr.tr("Search below, or enter a city or latitude,longitude")
            placeholderText: Tr.tr("No weather location saved")
            value: Weather.savedLocation
            onEditingFinished: value => Weather.setLocation(value)
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: weatherLocationColumn.implicitHeight + Tokens.padding.largeIncreased * 2

            ColumnLayout {
                id: weatherLocationColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    SearchBar {
                        id: weatherSearch

                        Layout.fillWidth: true
                        placeholderText: Tr.tr("Search for a city or place")
                        onAccepted: root.searchWeather()
                    }

                    IconButton {
                        icon: "search"
                        type: IconButton.Filled
                        enabled: weatherSearch.text.trim().length > 0 && !Weather.searchPending
                        opacity: enabled ? 1 : 0.5
                        onClicked: root.searchWeather()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Weather.searchMessage
                    text: Weather.searchMessage
                    color: Colours.palette.m3error
                    font: Tokens.font.label.small
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: Weather.searchResults

                    RowButton {
                        required property var modelData

                        icon: "location_on"
                        text: modelData.displayName
                        subtext: modelData.countryCode
                        onClicked: {
                            Weather.saveLocation(modelData);
                            weatherSearch.clear();
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.savedLocation
                            ? Tr.tr("Saved: %1").arg(Weather.savedLocation)
                            : Tr.tr("Weather follows a location you choose; it never asks the network for your IP")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        wrapMode: Text.WordWrap
                    }

                    TextButton {
                        visible: Weather.savedLocation.length > 0
                        text: Tr.tr("Clear")
                        onClicked: {
                            Weather.clearLocation();
                            weatherSearch.clear();
                        }
                    }
                }
            }
        }

        SelectRow {
            last: true
            label: Tr.tr("Weather language")
            subtext: Tr.tr("Language for place searches and weather text")
            active: menuItems.find(i => i.modelData === GlobalConfig.services.weatherLanguage) ?? weatherAutoLang
            onSelected: item => {
                GlobalConfig.services.weatherLanguage = item.modelData ?? "";
            }

            menuItems: [weatherAutoLang, ...weatherLangItems.instances]

            MenuItem {
                id: weatherAutoLang

                text: Tr.tr("Auto")
            }

            Variants {
                id: weatherLangItems

                model: Tr.supportedLanguages

                MenuItem {
                    required property string modelData

                    text: {
                        const locale = Qt.locale(modelData);
                        return locale.name === "C" ? modelData : locale.nativeLanguageName || locale.name;
                    }
                }
            }
        }

        // Weather provider
        SectionHeader {
            text: Tr.tr("Weather provider")
        }

        TextFieldRow {
            first: true
            label: Tr.tr("Provider URL")
            subtext: Tr.tr("Open-Meteo-compatible endpoint; weather.conf overrides this value")
            placeholderText: "https://api.open-meteo.com/v1/forecast"
            value: GlobalConfig.services.weatherProviderUrl
            onEditingFinished: value => GlobalConfig.services.weatherProviderUrl = value.trim()
        }

        TextFieldRow {
            label: Tr.tr("Geocoding URL")
            subtext: Tr.tr("Endpoint used when searching for a place")
            placeholderText: "https://geocoding-api.open-meteo.com/v1/search"
            value: GlobalConfig.services.weatherGeocodingUrl
            onEditingFinished: value => GlobalConfig.services.weatherGeocodingUrl = value.trim()
        }

        TextFieldRow {
            last: true
            label: Tr.tr("API key")
            subtext: Tr.tr("Optional; prefer ~/.config/padilha/weather.conf, which is never committed")
            placeholderText: Tr.tr("No key")
            value: GlobalConfig.services.weatherApiKey
            echoMode: TextInput.Password
            onEditingFinished: value => GlobalConfig.services.weatherApiKey = value.trim()
        }

        // Units
        SectionHeader {
            text: Tr.tr("Units")
        }

        SelectRow {
            first: true
            label: Tr.tr("Temperature")
            subtext: Tr.tr("Units for weather temperatures")
            menuItems: root.tempItems
            active: root.tempItems.find(i => i.value === GlobalConfig.services.weatherUnits)
            onSelected: item => GlobalConfig.services.weatherUnits = item.value
        }

        SelectRow {
            label: Tr.tr("System temperatures")
            subtext: Tr.tr("Units for CPU and GPU temperatures")
            menuItems: root.tempItems
            active: root.tempItems.find(i => i.value === GlobalConfig.services.sensorUnits)
            onSelected: item => GlobalConfig.services.sensorUnits = item.value
        }

        SelectRow {
            last: true
            label: Tr.tr("Data sizes")
            subtext: Tr.tr("Units for data sizes and network speeds")
            menuItems: root.dataItems
            active: root.dataItems.find(i => i.value === GlobalConfig.services.dataUnits)
            onSelected: item => GlobalConfig.services.dataUnits = item.value
        }

        // Weather updates
        SectionHeader {
            text: Tr.tr("Weather updates")
        }

        StepperRow {
            first: true
            label: Tr.tr("Refresh interval")
            subtext: Tr.tr("How often weather is fetched (minutes, 5–360)")
            value: Math.round(GlobalConfig.services.weatherRefreshInterval / 60)
            from: 5
            to: 360
            stepSize: 5
            onMoved: v => GlobalConfig.services.weatherRefreshInterval = Math.round(v * 60)
        }

        StepperRow {
            last: true
            label: Tr.tr("Cache lifetime")
            subtext: Tr.tr("How long saved weather stays usable without a request (minutes)")
            value: Math.round(GlobalConfig.services.weatherCacheTtl / 60)
            from: 5
            to: 1440
            stepSize: 5
            onMoved: v => GlobalConfig.services.weatherCacheTtl = Math.round(v * 60)
        }

        // Time & date
        SectionHeader {
            text: Tr.tr("Time & date")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("Clock format")
            subtext: Tr.tr("How times are shown across the shell")
            menuItems: root.clockItems
            active: root.clockItems.find(i => i.value === GlobalConfig.services.clockFormat)
            onSelected: item => GlobalConfig.services.clockFormat = item.value
        }
    }
}
