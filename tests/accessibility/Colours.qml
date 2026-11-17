pragma Singleton

// Minimal palette for the accessibility load harness. The real theme is
// covered by the contrast fixture; this stub keeps the QML test independent of
// a live Hyprland/Wayland session and of the user's wallpaper.
import QtQuick
import Quickshell

Singleton {
    readonly property bool light: false
    readonly property var palette: QtObject {
        property color m3primary: "#d0bcff"
        property color m3onPrimary: "#381e72"
        property color m3secondary: "#ccc2dc"
        property color m3onSecondary: "#332d41"
        property color m3secondaryContainer: "#4a4458"
        property color m3onSecondaryContainer: "#e8def8"
        property color m3tertiary: "#efb8c8"
        property color m3onTertiary: "#492532"
        property color m3surface: "#141218"
        property color m3onSurface: "#e6e0e9"
        property color m3surfaceContainer: "#211f26"
        property color m3surfaceContainerHighest: "#36343b"
        property color m3onSurfaceVariant: "#cac4d0"
        property color m3outline: "#938f99"
        property color m3outlineVariant: "#49454f"
        property color m3error: "#f2b8b5"
        property color m3onError: "#601410"
        property color m3primaryContainer: "#4f378b"
        property color m3onPrimaryContainer: "#eaddff"
        property color m3onErrorContainer: "#f9dedc"
    }

    readonly property var tPalette: palette

    function layer(c: color, layer: int): color {
        return c;
    }

    function on(c: color): color {
        return c;
    }
}
