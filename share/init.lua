-- Padilha user config.
--
-- Everything here is data: the compiler merges it over the shell's built-in
-- defaults and writes the JSON the shell reads. Machine-specific overrides go
-- in local.lua next to this file (same shape, wins over this table).
--
--   ~/.config/padilha/init.lua         this file
--   ~/.config/padilha/local.lua        per-machine, gitignored
--
-- padilha.array{} marks an empty list, because Lua cannot tell an empty list
-- from an empty map.

return {
    appearance = {
        transparency = {
            enabled = false, -- opaque bar and drawers
        },
    },

    general = {
        idle = {
            timeouts = padilha.array {}, -- no automatic lock/suspend on idle
        },
    },
}
