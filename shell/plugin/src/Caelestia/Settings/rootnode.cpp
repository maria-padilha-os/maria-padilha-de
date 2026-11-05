#include "rootnode.hpp"

#include <qjsonobject.h>
#include <qlogging.h>
#include <qprocess.h>
#include <qstandardpaths.h>
#include <qtimer.h>

namespace caelestia::settings {

RootNode::RootNode(const QString& path, RootNode* fallback, QObject* parent)
    : ObjectNode(fallback, parent)
    , m_file(new SettingsFile(path, this))
    , m_captureTimer(new QTimer(this)) {
    m_captureTimer->setSingleShot(true);
    m_captureTimer->setInterval(400);
    QObject::connect(m_captureTimer, &QTimer::timeout, this, &RootNode::captureToLua);

    QObject::connect(batcher(), &ChangeBatcher::dirtied, this, &RootNode::saveToFile);
    QObject::connect(m_file, &SettingsFile::changed, this, &RootNode::reloadFromFile);
    // Coalesce a burst of saves (a dragged slider) into one capture.
    QObject::connect(m_file, &SettingsFile::saved, this, [this] { m_captureTimer->start(); });
    QObject::connect(m_file, &SettingsFile::readFailed, this, [this](const QString& error) {
        emit treeLoadFailed(this, error);
    });
    QObject::connect(m_file, &SettingsFile::writeFailed, this, [this](const QString& error) {
        emit treeSaveFailed(this, error);
    });
}

void RootNode::load() {
    if (m_file->load() != SettingsFile::LoadResult::Changed)
        reloadFromFile();
}

QList<Diagnostic> RootNode::diagnostics() const {
    return m_diagnostics;
}

void RootNode::reloadFromFile() {
    const auto oldDiagnostics = m_diagnostics;
    m_diagnostics.clear();

    const auto data = m_file->read();
    syncJson(data ? data.value() : QJsonObject(), m_diagnostics);

    if (m_diagnostics != oldDiagnostics)
        emit diagnosticsChanged();

    emit treeLoaded(this);
}

void RootNode::saveToFile() {
    m_file->write(toJson());
}

void RootNode::captureToLua() {
    // The session exports the compiler it ran, so a checkout and a packaged
    // install both name their own binary; a shell started by hand falls back
    // to PATH.
    QString command = qEnvironmentVariable("PADILHA_CONFIG");
    if (command.isEmpty())
        command = qEnvironmentVariable("LILITH_CONFIG");
    if (command.isEmpty())
        command = QStandardPaths::findExecutable(QStringLiteral("padilha-config"));
    if (command.isEmpty())
        command = QStandardPaths::findExecutable(QStringLiteral("lilith-config"));
    if (command.isEmpty()) {
        qWarning("padilha-config not found; settings edits stay in shell.json");
        return;
    }

    // Promote the shell's JSON edits into the Lua source the next compile
    // reads. Detached: a settings save must not wait for it.
    if (!QProcess::startDetached(command, { QStringLiteral("capture"), QStringLiteral("--quiet") }))
        qWarning("Failed to start %s capture", qUtf8Printable(command));
}

} // namespace caelestia::settings
