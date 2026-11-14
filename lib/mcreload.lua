-- Tell a running Midnight Commander instance to reload its skin.
--
-- Upstream mc has no SIGUSR1 handler, so signalling it would terminate the
-- process. The Maria Padilha fork advertises "live-skin-reload" in `mc -V`;
-- only that build is safe to poke. The environment escape hatch is used by
-- the theme tests and by callers that deliberately want to suppress reloads.

local M = {}

function M.reload_running()
    if os.getenv("PADILHA_MC_RELOAD") == "0" then
        return false
    end

    local p = io.popen("mc -V 2>/dev/null")
    if not p then
        return false
    end
    local out = p:read("*a") or ""
    p:close()

    if not out:find("live-skin-reload", 1, true) then
        return false
    end

    -- -x avoids matching wrappers or unrelated mcedit processes. The signal
    -- is sent to the mc PID, never its process group; children keep the
    -- default action.
    os.execute("pkill -USR1 -x mc 2>/dev/null || true")
    return true
end

return M
