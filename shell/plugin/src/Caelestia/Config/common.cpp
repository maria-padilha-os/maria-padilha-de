#include "common.hpp"

#include <qdir.h>
#include <qstandardpaths.h>

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

Q_LOGGING_CATEGORY(lcConfig, "caelestia.config", QtInfoMsg)

QString configDir() {
    const auto configHome = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    const auto padilhaDir = configHome + u"/padilha"_s;

    if (QDir(padilhaDir).exists())
        return padilhaDir;

    // Compatibility with a pre-rename install: use the old directory only when
    // the new one is absent. Never create the old name ourselves.
    const auto legacyDir = configHome + u"/lilith"_s;
    if (QDir(legacyDir).exists())
        return legacyDir;

    return padilhaDir;
}

QString monitorConfigDir() {
    return configDir() + u"/monitors"_s;
}

} // namespace caelestia::config
