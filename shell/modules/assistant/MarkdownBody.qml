import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services

ColumnLayout {
    id: root

    property string text: ""
    property bool streaming: false
    property bool allowPrivileged: false
    property real fontScale: 0.92
    property var segments: parse(text)

    signal copyRequested(string text)

    spacing: Tokens.spacing.small

    function parse(raw: string): var {
        const src = raw || "";
        const out = [];
        const fence = /(^|\n)\x60\x60\x60([^\n\x60]*)\n([\s\S]*?)(?:\n\x60\x60\x60|$)/g;
        let last = 0;
        let match;
        while ((match = fence.exec(src)) !== null) {
            const start = match.index + (match[1] ? match[1].length : 0);
            if (start > last)
                out.push({
                    kind: "text",
                    text: src.slice(last, start)
                });
            let code = match[3];
            if (code.endsWith("\n"))
                code = code.slice(0, -1);
            out.push({
                kind: "code",
                language: (match[2] || "").trim(),
                code: code
            });
            last = fence.lastIndex;
        }
        if (last < src.length)
            out.push({
                kind: "text",
                text: src.slice(last)
            });
        return out.length > 0 ? out : [{
                kind: "text",
                text: src
            }];
    }

    Repeater {
        model: root.segments

        delegate: ColumnLayout {
            id: segment

            required property var modelData

            Layout.fillWidth: true
            spacing: 0

            TextEdit {
                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight
                visible: segment.modelData.kind !== "code"
                readOnly: true
                selectByMouse: true
                persistentSelection: true
                text: segment.modelData.kind === "text" ? segment.modelData.text : ""
                textFormat: TextEdit.MarkdownText
                wrapMode: TextEdit.Wrap
                font: Tokens.font.body.builders.small.scale(root.fontScale).build()
                color: Colours.palette.m3onSurface
                selectionColor: Colours.palette.m3primary
                selectedTextColor: Colours.palette.m3onPrimary
            }

            CodeBlock {
                Layout.fillWidth: true
                visible: segment.modelData.kind === "code"
                code: segment.modelData.kind === "code" ? segment.modelData.code : ""
                language: segment.modelData.kind === "code" ? segment.modelData.language : ""
                streaming: root.streaming
                allowPrivileged: root.allowPrivileged

                onCopyRequested: text => root.copyRequested(text)
            }
        }
    }
}
