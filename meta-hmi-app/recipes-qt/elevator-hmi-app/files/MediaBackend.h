#pragma once

#include <QFileSystemWatcher>
#include <QImage>
#include <QMediaPlayer>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QVideoSink>

// SD-card media inventory for the HMI video/ad pane.
//
// Two kinds of media, deliberately handled differently because only one of them
// can reach the glass today:
//
//   IMAGES (.jpg/.png/...) — PLAYABLE NOW. QML `Image` is a raster blit, so it
//     works under the software renderer on linuxfb with no GPU and no KMS. This
//     is the ad/slideshow path and it is live.
//
//   CLIPS (.mp4/...) — INVENTORIED ONLY. Decoding is not the blocker; getting
//     frames on the panel is. BLK-015: KMS never latches, so a VPU overlay or an
//     EGLFS VideoOutput would decode correctly and still be invisible. The pane
//     therefore lists clips and refuses to pretend it can play them.
//
// Stage 2 (after BLK-015): add Qt Multimedia / GStreamer VPU playback here,
// reusing `clips()`. Do not add VideoOutput until the modetest dumb-buffer test
// passes on glass.
//
// Per CLAUDE.md §8 this exposes state via Q_PROPERTY/signals only; no UI in C++.

class MediaBackend : public QObject
{
    Q_OBJECT
    // Card / mount
    Q_PROPERTY(bool mounted READ mounted NOTIFY mediaChanged)
    Q_PROPERTY(QString status READ status NOTIFY mediaChanged)
    Q_PROPERTY(QString mountPath READ mountPath CONSTANT)

    // Video clips — inventory only until BLK-015 is fixed.
    Q_PROPERTY(int clipCount READ clipCount NOTIFY mediaChanged)
    Q_PROPERTY(QString clipName READ clipName NOTIFY mediaChanged)
    Q_PROPERTY(QStringList clips READ clips NOTIFY mediaChanged)
    Q_PROPERTY(bool hasClips READ hasClips NOTIFY mediaChanged)
    // Software-decoded playback. DEMO ONLY — see VideoSurface.h for why this
    // exists at all and why it must go once BLK-015 is fixed.
    Q_PROPERTY(bool videoPlaying READ videoPlaying NOTIFY videoStateChanged)
    Q_PROPERTY(bool videoShowing READ videoShowing NOTIFY frameChanged)
    Q_PROPERTY(QString videoError READ videoError NOTIFY videoStateChanged)

    // Still images — the live slideshow path.
    Q_PROPERTY(int imageCount READ imageCount NOTIFY mediaChanged)
    Q_PROPERTY(QStringList images READ images NOTIFY mediaChanged)
    Q_PROPERTY(bool hasImages READ hasImages NOTIFY mediaChanged)
    Q_PROPERTY(QUrl imageSource READ imageSource NOTIFY slideChanged)
    Q_PROPERTY(QString imageName READ imageName NOTIFY slideChanged)
    Q_PROPERTY(int imageIndex READ imageIndex NOTIFY slideChanged)
    Q_PROPERTY(int slideIntervalMs READ slideIntervalMs WRITE setSlideIntervalMs NOTIFY slideIntervalChanged)

public:
    explicit MediaBackend(QObject *parent = nullptr);

    bool mounted() const { return m_mounted; }
    QString status() const { return m_status; }
    QString mountPath() const { return m_mountPath; }

    int clipCount() const { return m_clips.size(); }
    QString clipName() const;
    QStringList clips() const { return m_clips; }
    bool hasClips() const { return !m_clips.isEmpty(); }

    bool videoPlaying() const { return m_videoPlaying; }
    // True only once a frame has actually been decoded, so the pane never hides
    // its chrome for a clip that turns out to be undecodable.
    bool videoShowing() const { return !m_frame.isNull(); }
    QString videoError() const { return m_videoError; }
    const QImage &frame() const { return m_frame; }

    int imageCount() const { return m_images.size(); }
    QStringList images() const { return m_images; }
    bool hasImages() const { return !m_images.isEmpty(); }
    QUrl imageSource() const;
    QString imageName() const;
    int imageIndex() const { return m_imageIndex; }

    int slideIntervalMs() const { return m_slide.interval(); }
    void setSlideIntervalMs(int ms);

public slots:
    // Manual advance, so the slideshow can be driven from QML or a diagnostic.
    void nextImage();
    void refresh() { rescan(); }
    void playClip(int index = 0);
    void stopVideo();

signals:
    void mediaChanged();
    void slideChanged();
    void slideIntervalChanged();
    void frameChanged();
    void videoStateChanged();

private slots:
    void rescan();

private:
    void scanDir(const QString &path, int depth, QStringList *clips, QStringList *images);
    void restartSlideshow();

    QString m_mountPath;
    bool m_mounted = false;
    QString m_status;
    QStringList m_clips;
    QStringList m_images;
    int m_imageIndex = 0;
    QFileSystemWatcher m_watcher;
    QTimer m_poll;
    QTimer m_slide;

    QMediaPlayer m_player;
    QVideoSink m_sink;
    QImage m_frame;
    bool m_videoPlaying = false;
    QString m_videoError;
};
