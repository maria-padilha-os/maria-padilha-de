-- ADR 0001 sketch — last-line path checks over an already canonical path.
--
-- This is NOT a filesystem implementation. It does not call realpath, open,
-- stat, or openat2. The real backend must resolve symlinks and open the file
-- with openat2(2) (or the stricter component walk) before calling a function
-- like decide(). This file exists to make the root/deny rules reviewable.

local M = {}

-- Denied path components, at any depth. The leading dot matters.
M.deny_segments = {
    [".ssh"] = true,
    [".gnupg"] = true,
    [".dsh"] = true,
    [".aws"] = true,
    [".kube"] = true,
    [".password-store"] = true,
    [".mozilla"] = true,
}

-- Denied basenames, at any depth.
M.deny_basenames = {
    ["env.local.lua"] = true,
    ["ai.lua"] = true,
    ["ai.roots.lua"] = true,
    ["ai.key"] = true,
    ["known_hosts"] = true,
    ["authorized_keys"] = true,
    ["id_rsa"] = true,
    ["id_ed25519"] = true,
    ["id_ecdsa"] = true,
    [".netrc"] = true,
    [".git-credentials"] = true,
    [".npmrc"] = true,
    [".pypirc"] = true,
    ["logins.json"] = true,
    ["key4.db"] = true,
    ["cert9.db"] = true,
    ["Cookies"] = true,
    ["Login Data"] = true,
    [".bash_history"] = true,
    [".zsh_history"] = true,
}

-- Denied canonical prefixes. Keep these as full directories, not bare
-- substrings; `under()` adds the component boundary.
M.deny_prefixes = {
    "/home/u/.config/padilha/ai.lua",
    "/home/u/.config/padilha/ai.roots.lua",
    "/home/u/.config/padilha/ai.key",
    "/home/u/.local/state/padilha/ai",
    "/home/u/.config/google-chrome",
    "/home/u/.config/chromium",
    "/home/u/.config/BraveSoftware",
    "/home/u/.config/microsoft-edge",
    "/home/u/.config/vivaldi",
    "/home/u/.config/opera",
    "/home/u/.var/app/org.mozilla.firefox",
    "/home/u/.var/app/com.google.Chrome",
    "/home/u/.var/app/com.brave.Browser",
}

local function components(path)
    local out = {}
    for part in path:gmatch("[^/]+") do
        out[#out + 1] = part
    end
    return out
end

-- Component-boundary prefix check: /home/u/Doc is not under /home/u/Documents.
function M.under(path, root)
    if path == root then
        return true
    end
    if root == "/" then
        return path:sub(1, 1) == "/"
    end
    return path:sub(1, #root + 1) == root .. "/"
end

function M.denied(path)
    for _, prefix in ipairs(M.deny_prefixes) do
        if M.under(path, prefix) then
            return true, "denied_prefix"
        end
    end
    for _, part in ipairs(components(path)) do
        if M.deny_segments[part] then
            return true, "denied_component:" .. part
        end
        if M.deny_basenames[part] then
            return true, "denied_basename:" .. part
        end
    end
    return false
end

-- roots: { { path = "/home/u/Documents", mode = "ro" }, ... }
-- mode: "ro" | "rw"; global_write: boolean
function M.decide(path, roots, operation, global_write)
    if type(path) ~= "string" or path == "" or path:find("%z") then
        return false, "invalid_path"
    end
    if path:sub(1, 1) ~= "/" then
        return false, "not_absolute"
    end
    if path:find("%.%.") then
        return false, "dotdot"
    end

    local best = nil
    for _, root in ipairs(roots) do
        if M.under(path, root.path) then
            if best == nil or #root.path > #best.path then
                best = root
            end
        end
    end

    if best == nil then
        return false, "outside_root"
    end

    local denied, why = M.denied(path)
    if denied then
        return false, why
    end

    if operation == "read" or operation == "list" then
        return true, "allow_" .. best.mode
    end
    if operation == "write" then
        if best.mode ~= "rw" or not global_write then
            return false, "read_only"
        end
        return true, "allow_write"
    end
    return false, "unknown_operation"
end

-- Sketch-only smoke test: `lua policy.lua` prints a few decisions.
if arg and arg[0] and arg[0]:match("policy%.lua$") then
    local roots = {
        { path = "/home/u/Documents", mode = "ro" },
        { path = "/home/u/Projects", mode = "rw" },
    }
    local cases = {
        { "/home/u/Documents/notes.md", "read" },
        { "/home/u/Documents/.ssh/id_ed25519", "read" },
        { "/home/u/Documents/../.ssh/id_rsa", "read" },
        { "/home/u/Doc/notes.md", "read" },
        { "/home/u/Projects/a.txt", "write" },
        { "/home/u/Projects/a.txt", "read" },
    }
    for _, case in ipairs(cases) do
        local ok, why = M.decide(case[1], roots, case[2], false)
        print(string.format("%-5s %-55s %s", tostring(ok), case[1], why))
    end
end

return M
