local vars = require("variables")

hl.config({
    input = {
        -- Brazilian ABNT2. The lock screen now composes dead keys through a
        -- real TextInput, so the US fallback workaround is no longer needed.
        kb_layout          = "br",
        kb_options         = "",
        numlock_by_default = false,
        repeat_delay       = 250,
        repeat_rate        = 35,
        focus_on_close     = 1,

        touchpad           = {
            natural_scroll       = true,
            disable_while_typing = vars.touchpadDisableTyping,
            scroll_factor        = vars.touchpadScrollFactor,
        },
    },

    binds = {
        scroll_event_delay = 0,
    },

    cursor = {
        hotspot_padding = 1,
    },
})
