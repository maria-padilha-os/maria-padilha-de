#pragma once

#include "common.hpp"
#include "objectnode.hpp"
#include "settingsfile.hpp"

class QTimer;

namespace caelestia::settings {

class RootNode : public ObjectNode {
    Q_OBJECT

    Q_PROPERTY(QList<caelestia::settings::Diagnostic> diagnostics READ diagnostics NOTIFY diagnosticsChanged)

public:
    explicit RootNode(const QString& path, RootNode* fallback, QObject* parent = nullptr);

    [[nodiscard]] QList<Diagnostic> diagnostics() const;

    void load();

signals:
    void diagnosticsChanged();
    void treeLoaded(RootNode* self);
    void treeLoadFailed(RootNode* self, const QString& error);
    void treeSaveFailed(RootNode* self, const QString& error);

private:
    SettingsFile* const m_file;
    QTimer* m_captureTimer;
    QList<Diagnostic> m_diagnostics;

    void reloadFromFile();
    void saveToFile();
    void captureToLua();
};

} // namespace caelestia::settings
