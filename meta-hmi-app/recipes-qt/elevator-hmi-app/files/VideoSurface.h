#pragma once

#include <QImage>
#include <QQuickPaintedItem>

class MediaBackend;

// Paints decoded video frames into the Qt Quick scene.
//
// WHY NOT VideoOutput: Qt Quick's `VideoOutput` builds a QSGVideoNode, which the
// SOFTWARE scene-graph adaptation does not implement — under
// QT_QUICK_BACKEND=software it renders nothing. And we cannot leave software
// rendering, because BLK-015 means KMS scanout never reaches this panel.
//
// QQuickPaintedItem works in the software backend, so we take the decoded frame
// as a QImage from MediaBackend and blit it ourselves. That lands in the same
// /dev/fb0 the rest of the HMI is drawn into — the one path proven to display.
//
// This is DEMO-ONLY. The product path is GStreamer + gst-plugins-rockchip
// zero-copy VPU on a DRM plane (ADR-001 / CLAUDE.md §1), which needs BLK-015
// fixed. Software decode does not meet the 24/7 thermal budget.
class VideoSurface : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(MediaBackend *backend READ backend WRITE setBackend NOTIFY backendChanged)
    // false = PreserveAspectCrop (fill the well, lose the edges) — right for an
    // ad pane. true = PreserveAspectFit (letterbox) — right for cinema/fullscreen
    // layouts, where cropping a 16:9 clip into a portrait panel would discard
    // most of the picture.
    Q_PROPERTY(bool fit READ fit WRITE setFit NOTIFY fitChanged)

public:
    explicit VideoSurface(QQuickItem *parent = nullptr);

    MediaBackend *backend() const { return m_backend; }
    void setBackend(MediaBackend *b);

    bool fit() const { return m_fit; }
    void setFit(bool f);

    void paint(QPainter *painter) override;

signals:
    void backendChanged();
    void fitChanged();

private:
    MediaBackend *m_backend = nullptr;
    bool m_fit = false;
};
