#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>

// SD-card clip inventory for the HMI video pane.
//
// Stage 1 (this class): watch /media/sdcard, scan for video files, expose
// Q_PROPERTY to QML. Does NOT decode or display frames.
// Stage 2 (after BLK-015): Qt Multimedia / GStreamer VPU playback using
// the same clip list. Do not add VideoOutput here until KMS scanout works.

class MediaBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool mounted READ mounted NOTIFY mediaChanged)
    Q_PROPERTY(int clipCount READ clipCount NOTIFY mediaChanged)
    Q_PROPERTY(QString clipName READ clipName NOTIFY mediaChanged)
    Q_PROPERTY(QString status READ status NOTIFY mediaChanged)
    Q_PROPERTY(QStringList clips READ clips NOTIFY mediaChanged)
    Q_PROPERTY(QString mountPath READ mountPath CONSTANT)

public:
    explicit MediaBackend(QObject *parent = nullptr);

    bool mounted() const { return m_mounted; }
    int clipCount() const { return m_clips.size(); }
    QString clipName() const;
    QString status() const { return m_status; }
    QStringList clips() const { return m_clips; }
    QString mountPath() const { return m_mountPath; }

signals:
    void mediaChanged();

private slots:
    void rescan();

private:
    void scanDir(const QString &path, int depth, QStringList *out);

    QString m_mountPath;
    bool m_mounted = false;
    QString m_status;
    QStringList m_clips;
    QFileSystemWatcher m_watcher;
    QTimer m_poll;
};
