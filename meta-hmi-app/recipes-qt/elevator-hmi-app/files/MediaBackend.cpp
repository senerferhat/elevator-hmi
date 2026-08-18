#include "MediaBackend.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStorageInfo>

namespace {
const QString kMountPath = QStringLiteral("/media/sdcard");
const int kMaxDepth = 2;

bool isVideo(const QString &name)
{
    const QString lower = name.toLower();
    return lower.endsWith(QLatin1String(".mp4"))
        || lower.endsWith(QLatin1String(".mkv"))
        || lower.endsWith(QLatin1String(".mov"))
        || lower.endsWith(QLatin1String(".m4v"))
        || lower.endsWith(QLatin1String(".avi"))
        || lower.endsWith(QLatin1String(".webm"))
        || lower.endsWith(QLatin1String(".ts"))
        || lower.endsWith(QLatin1String(".m2ts"));
}

bool pathIsMounted(const QString &path)
{
    const QStorageInfo info(path);
    if (!info.isValid() || !info.isReady())
        return false;
    // QStorageInfo on an empty unmounted dir reports the parent filesystem
    // (root). Require the mount point itself.
    return QFileInfo(info.rootPath()).canonicalFilePath()
        == QFileInfo(path).canonicalFilePath();
}
} // namespace

MediaBackend::MediaBackend(QObject *parent)
    : QObject(parent)
    , m_mountPath(kMountPath)
    , m_status(QStringLiteral("NO CARD"))
{
    m_watcher.addPath(QStringLiteral("/media"));
    if (QFileInfo::exists(m_mountPath))
        m_watcher.addPath(m_mountPath);

    connect(&m_watcher, &QFileSystemWatcher::directoryChanged,
            this, &MediaBackend::rescan);
    connect(&m_poll, &QTimer::timeout, this, &MediaBackend::rescan);
    m_poll.setInterval(1500);
    m_poll.start();
    rescan();
}

QString MediaBackend::clipName() const
{
    if (m_clips.isEmpty())
        return QString();
    return QFileInfo(m_clips.first()).fileName();
}

void MediaBackend::scanDir(const QString &path, int depth, QStringList *out)
{
    if (depth > kMaxDepth)
        return;
    QDir dir(path);
    const auto entries = dir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot,
                                           QDir::Name);
    for (const QFileInfo &info : entries) {
        if (info.isDir()) {
            scanDir(info.absoluteFilePath(), depth + 1, out);
            continue;
        }
        if (isVideo(info.fileName()))
            out->append(info.absoluteFilePath());
    }
}

void MediaBackend::rescan()
{
    const bool nowMounted = pathIsMounted(m_mountPath);
    QStringList next;
    QString status;
    if (!nowMounted) {
        status = QStringLiteral("NO CARD");
    } else {
        scanDir(m_mountPath, 0, &next);
        if (next.isEmpty())
            status = QStringLiteral("EMPTY");
        else
            status = QStringLiteral("READY");
        if (!m_watcher.directories().contains(m_mountPath))
            m_watcher.addPath(m_mountPath);
    }

    if (nowMounted == m_mounted && next == m_clips && status == m_status)
        return;

    m_mounted = nowMounted;
    m_clips = next;
    m_status = status;
    emit mediaChanged();
}
