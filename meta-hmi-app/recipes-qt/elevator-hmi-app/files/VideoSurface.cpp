#include "VideoSurface.h"

#include "MediaBackend.h"

#include <QPainter>

VideoSurface::VideoSurface(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    // Frames arrive as whole images; there is nothing to blend underneath, and
    // opaque painting lets the software renderer skip the backdrop.
    setOpaquePainting(true);
    setFillColor(Qt::black);
}

void VideoSurface::setBackend(MediaBackend *b)
{
    if (m_backend == b)
        return;
    if (m_backend)
        disconnect(m_backend, nullptr, this, nullptr);
    m_backend = b;
    if (m_backend) {
        connect(m_backend, &MediaBackend::frameChanged,
                this, [this]() { update(); });
    }
    emit backendChanged();
    update();
}

void VideoSurface::paint(QPainter *painter)
{
    if (!m_backend)
        return;
    const QImage &img = m_backend->frame();
    if (img.isNull())
        return;

    // PreserveAspectCrop, to match the still-image slideshow: a letterboxed ad
    // reads as a fault on a fixed-function display.
    QSizeF scaled(img.size());
    scaled.scale(width(), height(), Qt::KeepAspectRatioByExpanding);
    const QRectF dst(QPointF((width() - scaled.width()) / 2.0,
                             (height() - scaled.height()) / 2.0),
                     scaled);

    painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
    painter->drawImage(dst, img);
}
