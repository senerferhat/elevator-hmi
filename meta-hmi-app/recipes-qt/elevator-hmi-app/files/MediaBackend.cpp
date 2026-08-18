#include "MediaBackend.h"

#include <QDir>
#include <QFileInfo>
#include <QStorageInfo>
#include <QVideoFrame>

namespace {
const QString kMountPath = QStringLiteral("/media/sdcard");
const int kMaxDepth = 2;
// Long enough to read an ad, short enough that a lab demo shows it rotating.
const int kDefaultSlideMs = 7000;

bool hasSuffix(const QString &lower, std::initializer_list<const char *> exts)
{
    for (const char *e : exts) {
        if (lower.endsWith(QLatin1String(e)))
            return true;
    }
    return false;
}

bool isVideo(const QString &name)
{
    return hasSuffix(name.toLower(),
                     { ".mp4", ".mkv", ".mov", ".m4v", ".avi", ".webm", ".ts", ".m2ts" });
}

// Only formats qtbase can actually decode in this image: libqjpeg + built-in
// PNG/BMP + libqgif. Deliberately NOT webp/tiff — qtimageformats is not
// installed, so those would list as playable and then render nothing.
bool isImage(const QString &name)
{
    return hasSuffix(name.toLower(), { ".jpg", ".jpeg", ".png", ".bmp", ".gif" });
}

bool pathIsMounted(const QString &path)
{
    const QStorageInfo info(path);
    if (!info.isValid() || !info.isReady())
        return false;
    // QStorageInfo on an empty unmounted dir reports the PARENT filesystem
    // (rootfs), which would look like a mounted card with no files. Require the
    // mount point itself.
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

    // udev + inotify should cover insert/remove, but a card can also appear
    // without either firing usefully (mount races, whole-disk vs partition), so
    // poll as a backstop. Cheap: a stat plus a shallow readdir.
    connect(&m_poll, &QTimer::timeout, this, &MediaBackend::rescan);
    m_poll.setInterval(1500);
    m_poll.start();

    m_slide.setInterval(kDefaultSlideMs);
    connect(&m_slide, &QTimer::timeout, this, &MediaBackend::nextImage);

    // Software-decoded playback (DEMO ONLY, see VideoSurface.h). We pull frames
    // out of a QVideoSink rather than using a VideoOutput item, because the
    // software scene graph has no video node and would draw nothing.
    m_player.setVideoSink(&m_sink);
    // Ads loop forever; there is no operator to press play in a lift car.
    m_player.setLoops(QMediaPlayer::Infinite);
    // No QAudioOutput is attached on purpose: rk809-sound does not probe on this
    // board, and an unsatisfied audio sink can stall the pipeline.
    connect(&m_sink, &QVideoSink::videoFrameChanged, this,
            [this](const QVideoFrame &f) {
                if (!f.isValid())
                    return;
                const QImage img = f.toImage();
                if (img.isNull())
                    return;
                m_frame = img;
                emit frameChanged();
            });
    connect(&m_player, &QMediaPlayer::errorOccurred, this,
            [this](QMediaPlayer::Error, const QString &msg) {
                // Most likely cause here is an unsupported codec: this image has
                // jpegdec but NO H.264 decoder (gstreamer1.0-libav is
                // LICENSE_FLAGS=commercial and deliberately not installed).
                m_videoError = msg;
                m_videoPlaying = false;
                emit videoStateChanged();
            });

    rescan();
}

QString MediaBackend::clipName() const
{
    if (m_clips.isEmpty())
        return QString();
    return QFileInfo(m_clips.first()).fileName();
}

QUrl MediaBackend::imageSource() const
{
    if (m_images.isEmpty() || m_imageIndex < 0 || m_imageIndex >= m_images.size())
        return QUrl();
    return QUrl::fromLocalFile(m_images.at(m_imageIndex));
}

QString MediaBackend::imageName() const
{
    if (m_images.isEmpty() || m_imageIndex < 0 || m_imageIndex >= m_images.size())
        return QString();
    return QFileInfo(m_images.at(m_imageIndex)).fileName();
}

void MediaBackend::setSlideIntervalMs(int ms)
{
    // Guard against a 0/negative interval turning the slideshow into a busy
    // loop that would peg a core on a device with no GPU to spare.
    const int clamped = qMax(1000, ms);
    if (clamped == m_slide.interval())
        return;
    m_slide.setInterval(clamped);
    emit slideIntervalChanged();
}

void MediaBackend::nextImage()
{
    if (m_images.size() < 2)
        return;
    m_imageIndex = (m_imageIndex + 1) % m_images.size();
    emit slideChanged();
}

void MediaBackend::restartSlideshow()
{
    if (m_images.size() > 1) {
        m_slide.start();
    } else {
        m_slide.stop();
    }
}

void MediaBackend::scanDir(const QString &path, int depth, QStringList *clips, QStringList *images)
{
    if (depth > kMaxDepth)
        return;
    QDir dir(path);
    const auto entries = dir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot,
                                           QDir::Name);
    for (const QFileInfo &info : entries) {
        if (info.isDir()) {
            scanDir(info.absoluteFilePath(), depth + 1, clips, images);
            continue;
        }
        const QString name = info.fileName();
        if (isVideo(name))
            clips->append(info.absoluteFilePath());
        else if (isImage(name))
            images->append(info.absoluteFilePath());
    }
}

void MediaBackend::rescan()
{
    const bool nowMounted = pathIsMounted(m_mountPath);
    QStringList nextClips;
    QStringList nextImages;
    QString status;

    if (!nowMounted) {
        status = QStringLiteral("NO CARD");
    } else {
        scanDir(m_mountPath, 0, &nextClips, &nextImages);
        status = (nextClips.isEmpty() && nextImages.isEmpty())
            ? QStringLiteral("EMPTY")
            : QStringLiteral("READY");
        if (!m_watcher.directories().contains(m_mountPath))
            m_watcher.addPath(m_mountPath);
    }

    const bool sameMedia = (nowMounted == m_mounted)
        && (nextClips == m_clips)
        && (nextImages == m_images)
        && (status == m_status);
    if (sameMedia)
        return;

    // Keep showing the same file across a rescan when it is still present;
    // otherwise the poll would restart the slideshow every time anything on the
    // card changed.
    const QString showing = imageName().isEmpty() ? QString() : m_images.value(m_imageIndex);

    m_mounted = nowMounted;
    m_clips = nextClips;
    m_images = nextImages;

    const int keptIndex = showing.isEmpty() ? -1 : m_images.indexOf(showing);
    m_imageIndex = keptIndex >= 0 ? keptIndex : 0;

    m_status = status;
    restartSlideshow();

    // Auto-play: a lift car has no one to press play. Start the first clip when
    // one appears, and tear playback down when the card goes away so a stale
    // last frame cannot sit on the panel.
    if (m_clips.isEmpty()) {
        if (m_videoPlaying || !m_frame.isNull())
            stopVideo();
    } else if (!m_videoPlaying) {
        playClip(0);
    }

    emit mediaChanged();
    emit slideChanged();
}

void MediaBackend::playClip(int index)
{
    if (index < 0 || index >= m_clips.size())
        return;
    m_videoError.clear();
    m_player.setSource(QUrl::fromLocalFile(m_clips.at(index)));
    m_player.play();
    if (!m_videoPlaying) {
        m_videoPlaying = true;
        emit videoStateChanged();
    }
}

void MediaBackend::stopVideo()
{
    m_player.stop();
    m_player.setSource(QUrl());
    if (!m_frame.isNull()) {
        m_frame = QImage();
        emit frameChanged();
    }
    if (m_videoPlaying) {
        m_videoPlaying = false;
        emit videoStateChanged();
    }
}
