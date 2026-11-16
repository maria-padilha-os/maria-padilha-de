// Keyboard table for the Files tab.
//
// This file deliberately uses plain JavaScript and no QML types so the same
// table can be imported by Widget.qml and loaded by
// `tests/filemanager/keybindings.test.js` under Node. Actions are pure names;
// the widget decides what they do. A destructive action must carry
// `requiresConfirm: true` and the widget must ask before running it.
//
// The normal (Vim) table is the single source of truth for the binding tests.

var modeLabels = {
    normal: "NORMAL",
    search: "SEARCH"
};

var bindings = [
    {
        mode: "normal",
        token: "j",
        action: "moveDown",
        label: "j",
        description: "Move down",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "k",
        action: "moveUp",
        label: "k",
        description: "Move up",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "h",
        action: "goUp",
        label: "h",
        description: "Go to the parent folder",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "l",
        action: "open",
        label: "l",
        description: "Open the selected folder or file",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "gg",
        action: "first",
        label: "gg",
        description: "Go to the first entry",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "G",
        action: "last",
        label: "G",
        description: "Go to the last entry",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "Ctrl+d",
        action: "pageDown",
        label: "Ctrl+d",
        description: "Move one page down",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "Ctrl+u",
        action: "pageUp",
        label: "Ctrl+u",
        description: "Move one page up",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "/",
        action: "search",
        label: "/",
        description: "Search the current folder",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "Escape",
        action: "escape",
        label: "Esc",
        description: "Clear the search and return to normal mode",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "Enter",
        action: "open",
        label: "Enter",
        description: "Open the selected folder or file",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "Backspace",
        action: "goUp",
        label: "Backspace",
        description: "Go to the parent folder",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "Home",
        action: "first",
        label: "Home",
        description: "Go to the first entry",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "End",
        action: "last",
        label: "End",
        description: "Go to the last entry",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "PageUp",
        action: "pageUp",
        label: "Page Up",
        description: "Move one page up",
        requiresConfirm: false
    },
    {
        mode: "normal",
        token: "PageDown",
        action: "pageDown",
        label: "Page Down",
        description: "Move one page down",
        requiresConfirm: false
    }
];

// Kept in the module so a test can prove a future destructive binding is not
// silently accepted.
var destructiveActions = ["delete", "move", "rename", "remove", "trash"];

function isDestructive(action) {
    return destructiveActions.indexOf(String(action || "").toLowerCase()) !== -1;
}

function enabledBindings(mode) {
    return bindings.filter(function (binding) {
        return binding.mode === (mode || "normal");
    });
}

// Resolve one key token. `pending` carries the first `g` of a `gg` sequence.
// Returns { action, pending, consume, binding? }.
function resolve(token, ctrl, shift, pending) {
    var value = String(token || "");
    if (value.length === 0)
        return { action: "", pending: "", consume: false };

    var waitingForG = pending === "g";
    if (waitingForG) {
        if (!ctrl && !shift && value === "g")
            return { action: "first", pending: "", consume: true };
        pending = "";
    }

    if (!ctrl && !shift && value === "g")
        return { action: "", pending: "g", consume: true };

    // Ctrl chords are spelled "Ctrl+d"; grouped with the modifier so a Ctrl
    // chord can never fall through to the plain letter binding.
    var key = ctrl ? "Ctrl+" + value.toLowerCase() : value;
    for (var i = 0; i < bindings.length; i++) {
        var binding = bindings[i];
        if (binding.mode === "normal" && binding.token === key)
            return { action: binding.action, pending: "", consume: true, binding: binding };
    }

    return { action: "", pending: "", consume: false };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        bindings: bindings,
        modeLabels: modeLabels,
        destructiveActions: destructiveActions,
        isDestructive: isDestructive,
        enabledBindings: enabledBindings,
        resolve: resolve
    };
}
