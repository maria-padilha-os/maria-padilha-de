// Pure manifest validation and catalog helpers for the extension manager.
//
// Keeping this logic in a plain JavaScript module means the shell, the
// settings page and the Node tests all agree on what a valid extension is.
// The QML service imports it as `ExtensionManifest`; Node requires it as a
// CommonJS module (the guard at the bottom is ignored by QML).

// Translation helpers. Node tests load this module without QML, so every
// lookup falls back to the English source string there.
function trText(text) {
    return typeof Tr !== "undefined" && Tr && Tr.tr ? Tr.tr(text) : text;
}

function trArgs(text, args) {
    var values = args || [];
    if (typeof Tr === "undefined" || !Tr || !Tr.mark || !Tr.trMarked) {
        var result = text;
        for (var i = 0; i < values.length; ++i)
            result = result.replace("%" + (i + 1), String(values[i]));
        return result;
    }
    return Tr.trMarked(Tr.mark(text, values));
}

var REQUIRED_FIELDS = ["name", "description", "version", "icon", "tab"];

// Canonical capability names. Extensions may use a name this list does not
// know about; it is still shown, with a warning that its meaning is undefined.
var PERMISSIONS = {
    "filesystem": {
        label: "Files",
        description: "Reads and writes files."
    },
    "network": {
        label: "Network",
        description: "Connects to remote servers."
    },
    "microphone": {
        label: "Microphone",
        description: "Captures audio from the microphone."
    },
    "screen": {
        label: "Screen",
        description: "Reads pixels from the screen."
    },
    "notifications": {
        label: "Notifications",
        description: "Sends desktop notifications."
    },
    "processes": {
        label: "Processes",
        description: "Runs local commands and processes."
    },
    "system": {
        label: "System",
        description: "Reads system and filesystem information."
    },
    "clipboard": {
        label: "Clipboard",
        description: "Reads or writes the clipboard."
    }
};

function has(object, key) {
    return Object.prototype.hasOwnProperty.call(object, key);
}

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function asString(value) {
    return typeof value === "string" ? value.trim() : "";
}

function basename(path) {
    var cleaned = String(path || "").replace(/\\/g, "/").replace(/\/+$/, "");
    var parts = cleaned.split("/");
    return parts[parts.length - 1] || "";
}

// Shortcut comparison ignores case, surrounding spaces and whether the user
// wrote "Super+Alt+C" or "super + alt + c".
function normaliseShortcut(value) {
    if (typeof value !== "string")
        return "";
    var parts = value.toLowerCase().split("+");
    var result = [];
    for (var i = 0; i < parts.length; ++i) {
        var part = parts[i].trim().replace(/\s+/g, " ");
        if (part.length > 0)
            result.push(part);
    }
    return result.join("+");
}

function blankEntry(dirPath) {
    var id = basename(dirPath);
    return {
        id: id,
        dirPath: String(dirPath || ""),
        name: id,
        description: "",
        version: "",
        icon: "extension",
        shortcut: "",
        shortcutKey: "",
        tab: "",
        tabPath: "",
        tabUrl: "",
        tabExists: null,
        permissions: [],
        requires: [],
        commands: [],
        commandAvailability: null,
        dependencies: [],
        missingDependencies: [],
        missingCommands: [],
        errors: [],
        warnings: [],
        valid: false,
        canEnable: false,
        duplicateId: false,
        shadowed: false,
        shadowedBy: "",
        priority: 0,
        shortcutConflict: false,
        manifest: null
    };
}

function addError(entry, message) {
    if (entry.errors.indexOf(message) === -1)
        entry.errors.push(message);
}

function addWarning(entry, message) {
    if (entry.warnings.indexOf(message) === -1)
        entry.warnings.push(message);
}

function normaliseTabPath(tab) {
    var path = asString(tab).replace(/\\/g, "/");
    if (path.length === 0)
        return "";
    if (path.charAt(0) === "/" || /^[A-Za-z]:\//.test(path))
        return "";
    if (path.indexOf("\0") !== -1 || path.indexOf("\n") !== -1)
        return "";
    path = path.replace(/^\.\//, "");
    var parts = path.split("/");
    for (var i = 0; i < parts.length; ++i) {
        if (parts[i] === ".." || parts[i] === ".")
            return "";
    }
    return path;
}

function readStringList(value, field, entry) {
    var result = [];
    if (value === undefined || value === null)
        return result;
    if (!Array.isArray(value)) {
        addError(entry, trArgs("\"%1\" must be a list of strings.", [field]));
        return result;
    }
    for (var i = 0; i < value.length; ++i) {
        var item = asString(value[i]);
        if (item.length === 0) {
            addError(entry, trArgs("\"%1\" entries must be non-empty strings.", [field]));
            continue;
        }
        if (result.indexOf(item) !== -1) {
            addWarning(entry, trArgs("\"%1\" lists \"%2\" more than once.", [field, item]));
            continue;
        }
        result.push(item);
    }
    return result;
}

function mergeUnique(first, second) {
    var result = first.slice();
    for (var i = 0; i < second.length; ++i) {
        if (result.indexOf(second[i]) === -1)
            result.push(second[i]);
    }
    return result;
}

function knownPermission(permission) {
    return has(PERMISSIONS, permission) ? PERMISSIONS[permission] : null;
}

function permissionLabel(permission) {
    // Keep the literals here so xgettext can see every label, and translate
    // them on each call so a language switch needs no module reload.
    switch (permission) {
    case "filesystem":
        return trText("Files");
    case "network":
        return trText("Network");
    case "microphone":
        return trText("Microphone");
    case "screen":
        return trText("Screen");
    case "notifications":
        return trText("Notifications");
    case "processes":
        return trText("Processes");
    case "system":
        return trText("System");
    case "clipboard":
        return trText("Clipboard");
    default:
        return permission;
    }
}

function permissionDescription(permission) {
    switch (permission) {
    case "filesystem":
        return trText("Reads and writes files.");
    case "network":
        return trText("Connects to remote servers.");
    case "microphone":
        return trText("Captures audio from the microphone.");
    case "screen":
        return trText("Reads pixels from the screen.");
    case "notifications":
        return trText("Sends desktop notifications.");
    case "processes":
        return trText("Runs local commands and processes.");
    case "system":
        return trText("Reads system and filesystem information.");
    case "clipboard":
        return trText("Reads or writes the clipboard.");
    default:
        return trText("Custom capability; check the extension source before enabling it.");
    }
}

function permissionSummary(permissions) {
    if (!permissions || permissions.length === 0)
        return trText("No special permissions declared.");
    var labels = [];
    for (var i = 0; i < permissions.length; ++i)
        labels.push(permissionLabel(permissions[i]));
    return labels.join(", ");
}

function describeTab(extension) {
    if (!extension || !extension.tab)
        return trText("No tab is declared; this extension cannot be enabled.");
    return trArgs("Adds the %1 tab to the top panel, after Weather.", [extension.name]);
}

function describeShortcut(extension) {
    if (!extension || !extension.shortcut)
        return trText("No shortcut declared; open the tab from the top panel.");
    return trArgs("Press %1 to open or close the %2 tab; the shortcut enables it if necessary.", [extension.shortcut, extension.name]);
}

// Parse one manifest. `files` is the recursive file list of the extension
// directory (relative paths), which lets us report a missing tab as an error
// instead of waiting for the tab to fail at load time.
function parseEntry(dirPath, body, files) {
    var entry = blankEntry(dirPath);
    var text = typeof body === "string" ? body : "";
    var data = null;

    if (text.trim().length === 0) {
        addError(entry, trText("extension.json is empty. Add a JSON object with name, description, version, icon and tab."));
        return entry;
    }

    try {
        data = JSON.parse(text);
    } catch (error) {
        addError(entry, trArgs("extension.json is not valid JSON: %1. Fix the syntax near the reported problem.", [error.message]));
        return entry;
    }

    if (!isObject(data)) {
        addError(entry, trText("extension.json must contain one JSON object, not an array or scalar value."));
        return entry;
    }

    entry.manifest = data;

    for (var i = 0; i < REQUIRED_FIELDS.length; ++i) {
        var key = REQUIRED_FIELDS[i];
        var value = asString(data[key]);
        if (value.length === 0)
            addError(entry, trArgs("\"%1\" is required and must be a non-empty string.", [key]));
        else
            entry[key] = key === "name" || key === "description" ? trText(value) : value;
    }

    if (entry.id.length === 0)
        addError(entry, trText("The extension folder name is empty; the folder name is the extension id."));

    if (has(data, "shortcut") && data.shortcut !== null) {
        if (typeof data.shortcut !== "string") {
            addError(entry, trText("\"shortcut\" must be a string such as \"Super + Alt + X\"."));
        } else {
            entry.shortcut = data.shortcut.trim().replace(/\s+/g, " ");
            entry.shortcutKey = normaliseShortcut(entry.shortcut);
            if (entry.shortcut.length > 0 && entry.shortcutKey.length === 0)
                addError(entry, trText("\"shortcut\" is blank; remove the key or give it a key combination."));
        }
    }

    entry.permissions = mergeUnique(readStringList(data.permissions, "permissions", entry),
        readStringList(data.capabilities, "capabilities", entry));
    for (var p = 0; p < entry.permissions.length; ++p) {
        if (!has(PERMISSIONS, entry.permissions[p])) {
            addWarning(entry, trArgs("Unknown permission \"%1\". Known permissions are: %2.", [entry.permissions[p], Object.keys(PERMISSIONS).join(", ")]));
        }
    }

    entry.requires = mergeUnique(readStringList(data.requires, "requires", entry),
        readStringList(data.dependencies, "dependencies", entry));
    for (var r = 0; r < entry.requires.length; ++r) {
        if (entry.requires[r] === entry.id)
            addError(entry, trArgs("\"requires\" cannot name the extension itself (\"%1\").", [entry.id]));
    }

    entry.commands = readStringList(data.commands, "commands", entry);

    var tab = normaliseTabPath(entry.tab);
    if (entry.tab.length > 0 && tab.length === 0) {
        addError(entry, trText("\"tab\" must be a relative .qml path inside the extension folder, without \"..\" or a leading slash."));
    } else if (tab.length > 0) {
        if (!/\.qml$/i.test(tab))
            addError(entry, trArgs("\"tab\" must point to a .qml file, not \"%1\".", [entry.tab]));
        entry.tabPath = tab;
        entry.tabUrl = `file://${entry.dirPath.replace(/\/+$/, "")}/${tab}`;
        if (Array.isArray(files)) {
            entry.tabExists = files.indexOf(tab) !== -1;
            if (!entry.tabExists)
                addError(entry, trArgs("Tab file \"%1\" was not found in %2. Fix \"tab\" or add the file.", [tab, entry.dirPath]));
        }
    }

    return entry;
}

function finalise(entry) {
    entry.valid = entry.errors.length === 0;
    entry.canEnable = entry.valid && !entry.shadowed && entry.tab.length > 0 && entry.tabExists !== false && entry.missingDependencies.length === 0 && entry.missingCommands.length === 0;
    return entry;
}

// Build the whole catalog from every discovered folder. Duplicate ids are kept
// in the result (never silently dropped) and marked on every copy. Duplicate
// shortcuts are warnings: the tabs still work, but the shortcut is ambiguous.
function buildCatalog(entries, options) {
    options = options || {};
    var result = [];
    var i;

    for (i = 0; i < entries.length; ++i) {
        var raw = entries[i] || {};
        var parsed = parseEntry(raw.dirPath || "", raw.body || "", raw.files);
        parsed.priority = typeof raw.priority === "number" ? raw.priority : 0;
        if (raw.availableCommands !== undefined && raw.availableCommands !== null)
            parsed.commandAvailability = raw.availableCommands;
        result.push(parsed);
    }

    var byId = Object.create(null);
    for (i = 0; i < result.length; ++i) {
        var id = result[i].id;
        if (!byId[id])
            byId[id] = [];
        byId[id].push(result[i]);
    }
    for (var groupId in byId) {
        if (!has(byId, groupId))
            continue;
        var group = byId[groupId];
        if (group.length < 2)
            continue;

        var bestPriority = group[0].priority;
        for (i = 1; i < group.length; ++i)
            bestPriority = Math.min(bestPriority, group[i].priority);

        var winners = [];
        for (i = 0; i < group.length; ++i) {
            if (group[i].priority === bestPriority)
                winners.push(group[i]);
        }
        var winnerPaths = winners.map(entry => entry.dirPath);

        for (i = 0; i < group.length; ++i) {
            var entry = group[i];
            var others = [];
            for (var j = 0; j < group.length; ++j) {
                if (j !== i)
                    others.push(group[j].dirPath);
            }
            entry.duplicateId = true;

            if (entry.priority > bestPriority) {
                // The user folder intentionally overrides a bundled copy with
                // the same id. Keep the shadowed copy visible and explain why
                // only the higher-priority copy can be enabled.
                entry.shadowed = true;
                entry.shadowedBy = winnerPaths.join(", ");
                addWarning(entry, trArgs("Shadowed by %1: another folder has the same id \"%2\" at a higher priority. Only the higher-priority copy can be enabled.", [entry.shadowedBy, groupId]));
            } else if (winners.length > 1) {
                addError(entry, trArgs("Duplicate extension id \"%1\": also found in %2. Rename or remove one folder so the id is unique.", [groupId, others.join(", ")]));
            } else {
                addWarning(entry, trArgs("Overrides the same id \"%1\" in %2. Only this copy is used.", [groupId, others.join(", ")]));
            }
        }
    }

    var byShortcut = Object.create(null);
    for (i = 0; i < result.length; ++i) {
        if (result[i].shadowed)
            continue;
        var key = result[i].shortcutKey;
        if (key.length === 0)
            continue;
        if (!byShortcut[key])
            byShortcut[key] = [];
        byShortcut[key].push(result[i]);
    }
    for (var shortcutKey in byShortcut) {
        if (!has(byShortcut, shortcutKey))
            continue;
        var shortcutGroup = byShortcut[shortcutKey];
        if (shortcutGroup.length < 2)
            continue;
        for (i = 0; i < shortcutGroup.length; ++i) {
            var names = [];
            for (var k = 0; k < shortcutGroup.length; ++k) {
                if (k !== i)
                    names.push(`${shortcutGroup[k].name} (${shortcutGroup[k].id})`);
            }
            shortcutGroup[i].shortcutConflict = true;
            addWarning(shortcutGroup[i], trArgs("Shortcut \"%1\" is also used by %2. Change one manifest so the shortcut is unambiguous.", [shortcutGroup[i].shortcut, names.join(", ")]));
        }
    }

    var availableCommands = options.availableCommands || null;
    for (i = 0; i < result.length; ++i) {
        var entry = result[i];
        for (var r = 0; r < entry.requires.length; ++r) {
            var dependency = entry.requires[r];
            var matches = byId[dependency];
            var present = matches && matches.length > 0;
            entry.dependencies.push({
                id: dependency,
                present: !!present
            });
            if (!present) {
                entry.missingDependencies.push(dependency);
            } else {
                var usable = false;
                for (var m = 0; m < matches.length; ++m) {
                    if (matches[m].tab.length > 0)
                        usable = true;
                }
                if (!usable)
                    addWarning(entry, trArgs("Dependency \"%1\" is installed but has no usable tab.", [dependency]));
            }
        }
        if (entry.missingDependencies.length > 0) {
            addError(entry, trArgs("Missing extension dependency: %1. Install it in an extensions folder (nothing is downloaded automatically) or remove it from \"requires\".", [entry.missingDependencies.join(", ")]));
        }

        var entryCommands = entry.commandAvailability !== null ? entry.commandAvailability : availableCommands;
        if (entryCommands !== null && entry.commands.length > 0) {
            for (var c = 0; c < entry.commands.length; ++c) {
                var command = entry.commands[c];
                var found = entryCommands[command] === true || (entryCommands[command] !== undefined && entryCommands[command] !== false && entryCommands[command] !== "");
                if (!found) {
                    entry.missingCommands.push(command);
                    addError(entry, trArgs("Missing command \"%1\". Install it with your package manager or remove it from \"commands\".", [command]));
                }
            }
        }

        finalise(entry);
    }

    result.sort(function(a, b) {
        var byName = a.name.localeCompare(b.name);
        return byName !== 0 ? byName : a.id.localeCompare(b.id);
    });
    return result;
}

// The scanner prints EXTENSION:<dir>, a FILES:<relative paths> line, then the
// raw manifest. Parsing it here keeps the wire format testable without Qt.
function parseScanOutput(output) {
    var entries = [];
    var chunks = String(output || "").split("EXTENSION:");
    for (var i = 0; i < chunks.length; ++i) {
        var trimmed = chunks[i].trim();
        if (trimmed.length === 0)
            continue;

        var lines = trimmed.split("\n");
        var dirPath = (lines[0] || "").replace(/\/+$/, "");
        var files = null;
        var availableCommands = null;
        var priority = 0;
        var cursor = 1;
        if ((lines[cursor] || "").startsWith("PRIORITY:")) {
            priority = Number(lines[cursor].slice(9));
            if (!isFinite(priority))
                priority = 0;
            cursor += 1;
        }
        if ((lines[cursor] || "").startsWith("FILES:")) {
            files = lines[cursor].slice(6).split("\t").filter(name => name.length > 0);
            cursor += 1;
            if ((lines[cursor] || "").startsWith("COMMANDS:")) {
                var commandLine = lines[cursor].slice(9);
                if (commandLine !== "?") {
                    availableCommands = Object.create(null);
                    var pairs = commandLine.split("\t").filter(pair => pair.length > 0);
                    for (var p = 0; p < pairs.length; ++p) {
                        var equals = pairs[p].indexOf("=");
                        if (equals > 0)
                            availableCommands[pairs[p].slice(0, equals)] = pairs[p].slice(equals + 1);
                    }
                }
                cursor += 1;
            }
        }
        entries.push({
            dirPath: dirPath,
            body: lines.slice(cursor).join("\n").trim(),
            files: files,
            priority: priority,
            availableCommands: availableCommands
        });
    }
    return entries;
}

function catalogFromScan(output, options) {
    return buildCatalog(parseScanOutput(output), options);
}

function isEnabled(enabledIds, id) {
    return Array.isArray(enabledIds) && enabledIds.indexOf(id) !== -1;
}

// Return a new list. Keeping this pure makes the value that is written back to
// dashboard.extensionTabs easy to test without a running shell.
function setEnabled(enabledIds, id, enabled) {
    var current = Array.isArray(enabledIds) ? enabledIds.filter(value => typeof value === "string" && value.length > 0) : [];
    var hasId = current.indexOf(id) !== -1;
    if (typeof id !== "string" || id.length === 0 || enabled === hasId)
        return current;
    if (enabled)
        current.push(id);
    else
        current.splice(current.indexOf(id), 1);
    return current;
}

function filterCatalog(list, query, mode) {
    var needle = String(query || "").trim().toLowerCase();
    var selected = mode || "all";
    var result = [];
    for (var i = 0; i < (list || []).length; ++i) {
        var entry = list[i];
        if (selected === "enabled" && entry.enabled !== true)
            continue;
        if (selected === "disabled" && entry.enabled === true)
            continue;
        if (selected === "issues" && !(entry.errors.length > 0 || entry.warnings.length > 0))
            continue;
        if (needle.length > 0) {
            var haystack = [
                entry.id,
                entry.name,
                entry.description,
                entry.version,
                entry.shortcut,
                entry.permissions.join(" "),
                entry.requires.join(" "),
                entry.errors.join(" "),
                entry.warnings.join(" ")
            ].join(" ").toLowerCase();
            if (haystack.indexOf(needle) === -1)
                continue;
        }
        result.push(entry);
    }
    return result;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        REQUIRED_FIELDS: REQUIRED_FIELDS,
        PERMISSIONS: PERMISSIONS,
        normaliseShortcut: normaliseShortcut,
        normaliseTabPath: normaliseTabPath,
        permissionLabel: permissionLabel,
        permissionDescription: permissionDescription,
        permissionSummary: permissionSummary,
        describeTab: describeTab,
        describeShortcut: describeShortcut,
        parseEntry: parseEntry,
        buildCatalog: buildCatalog,
        parseScanOutput: parseScanOutput,
        catalogFromScan: catalogFromScan,
        isEnabled: isEnabled,
        setEnabled: setEnabled,
        filterCatalog: filterCatalog
    };
}
