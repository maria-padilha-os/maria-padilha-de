#pragma once

#include <qstringlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

class ClipboardConfig : public settings::ObjectNode {
    CONFIG_NODE(ClipboardConfig, settings::ObjectNode)

    // Opt-in: a daily-driver desktop should not keep a clipboard log until the
    // user asks for one.
    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(int, maxEntries, 100)
    CONFIG_PROPERTY(int, privateWindowDelay, 5)
    CONFIG_PROPERTY(int, maxEntryBytes, 1048576)
    CONFIG_PROPERTY(bool, showIndicator, true)
    CONFIG_PROPERTY(QStringList, denyClasses, {})
    CONFIG_PROPERTY(QStringList, denyTitles, {})
};

} // namespace caelestia::config
