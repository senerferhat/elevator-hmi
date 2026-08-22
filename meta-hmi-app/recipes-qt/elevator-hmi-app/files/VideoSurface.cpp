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

void VideoSurface::setFit(bool f)
{
    if (m_fit == f)
        return;
    m_fit = f;
    emit fitChanged();
    update();
}

void VideoSurface::paint(QPainter *painter)
{
    if (!m_backend)
        return;
    const QImage &img = m_backend->frame();
    if (img.isNull())
        return;

    // Crop by default, to match the still-image slideshow: a letterboxed ad
    // reads as a fault on a fixed-function display. Cinema layouts set fit=true
    // instead, because cropping 16:9 into a portrait panel would throw away most
    // of the frame.
    QSizeF scaled(img.size());
    scaled.scale(width(), height(),
                 m_fit ? Qt::KeepAspectRatio : Qt::KeepAspectRatioByExpanding);
    const QRectF dst(QPointF((width() - scaled.width()) / 2.0,
                             (height() - scaled.height()) / 2.0),
                     scaled);

    painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
    painter->drawImage(dst, img);
}
