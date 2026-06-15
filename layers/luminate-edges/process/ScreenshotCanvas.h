#pragma once
#include <QQuickPaintedItem>
#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QMouseEvent>
#include <QProcess>
#include <QDateTime>
#include <QDir>
#include <QStandardPaths>
#include <QTransform>
#include <QFont>
#include <QFontMetricsF>
#include <QLineF>
#include <QtMath>
#include <QGuiApplication>
#include <QClipboard>
#include <QMimeData>

struct AnnItem {
    int type; // 0=Stroke, 1=Rect, 2=Circle, 3=Arrow, 4=Pixelate, 5=Text, 6=Image
    QColor color;
    double width;
    QPolygonF points;
    QRectF rect;
    double rotation = 0.0;
    QString text;
    QImage image; 
    
    QRectF cachedRect;
    double cachedWidth = -1;
};

class ScreenshotCanvas : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(int activeMode READ activeMode WRITE setActiveMode NOTIFY modeChanged)
    Q_PROPERTY(int annMode READ annMode WRITE setAnnMode NOTIFY annModeChanged)
    Q_PROPERTY(QColor currentColor READ currentColor WRITE setCurrentColor NOTIFY colorChanged)
    Q_PROPERTY(double brushSize READ brushSize WRITE setBrushSize NOTIFY sizeChanged)
    Q_PROPERTY(double textSize READ textSize WRITE setTextSize NOTIFY textSizeChanged)
    Q_PROPERTY(double scaleFactor READ scaleFactor NOTIFY scaleChanged)
    Q_PROPERTY(bool isInteracting READ isInteracting NOTIFY isInteractingChanged)
    
    Q_PROPERTY(double currentRotation READ currentRotation WRITE setCurrentRotation NOTIFY rotationChanged)
    Q_PROPERTY(bool hasSelection READ hasSelection NOTIFY selectionChanged)
    Q_PROPERTY(bool isTextSelected READ isTextSelected NOTIFY selectionChanged)

    // NEW: Expose raw image dimensions to QML for dynamic window sizing
    Q_PROPERTY(int imageWidth READ imageWidth NOTIFY imageLoaded)
    Q_PROPERTY(int imageHeight READ imageHeight NOTIFY imageLoaded)

public:
    ScreenshotCanvas(QQuickItem *parent = nullptr) : QQuickPaintedItem(parent) {
        setAcceptedMouseButtons(Qt::LeftButton | Qt::RightButton);
        setAcceptHoverEvents(true);
    }

    int activeMode() const { return m_activeMode; }
    void setActiveMode(int m) { 
        m_activeMode = m; 
        m_selectedIndex = -1; 
        update(); 
        emit modeChanged();
        emit selectionChanged();
    }

    int annMode() const { return m_annMode; }
    void setAnnMode(int m) { 
        m_annMode = m; 
        if (m_annMode != 6) {
            m_selectedIndex = -1;
            emit selectionChanged();
        }
        emit annModeChanged(); 
    }

    bool hasSelection() const { return m_selectedIndex >= 0 && m_selectedIndex < m_annotations.size(); }
    bool isTextSelected() const { return hasSelection() && m_annotations[m_selectedIndex].type == 5; }

    double currentRotation() const {
        if (hasSelection()) return m_annotations[m_selectedIndex].rotation * 180.0 / M_PI;
        return 0.0;
    }
    void setCurrentRotation(double r) {
        if (hasSelection()) {
            m_annotations[m_selectedIndex].rotation = r * M_PI / 180.0;
            update();
            emit rotationChanged();
        }
    }

    QColor currentColor() const { return m_color; }
    void setCurrentColor(QColor c) { 
        m_color = c; 
        if (hasSelection()) {
            m_annotations[m_selectedIndex].color = c;
            update();
        }
        emit colorChanged(); 
    }

    double brushSize() const { return m_size; }
    void setBrushSize(double s) { 
        m_size = s; 
        if (hasSelection() && m_annotations[m_selectedIndex].type != 5 && m_annotations[m_selectedIndex].type != 6) {
            m_annotations[m_selectedIndex].width = s;
            update();
        }
        emit sizeChanged(); 
    }

    double textSize() const { return m_textSize; }
    void setTextSize(double s) {
        m_textSize = s;
        if (hasSelection() && m_annotations[m_selectedIndex].type == 5) {
            m_annotations[m_selectedIndex].width = s;
            QFont font("sans-serif");
            font.setPixelSize(qMax(1, qRound(s)));
            font.setBold(true);
            QFontMetricsF fm(font);
            QRectF br = fm.boundingRect(m_annotations[m_selectedIndex].text);
            m_annotations[m_selectedIndex].rect.setWidth(br.width());
            m_annotations[m_selectedIndex].rect.setHeight(br.height());
            update();
        }
        emit textSizeChanged();
    }

    double scaleFactor() const { return m_scale; }
    bool isInteracting() const { return m_isInteracting; }
    void setInteracting(bool val) { 
        if (m_isInteracting != val) { 
            m_isInteracting = val; 
            emit isInteractingChanged(); 
        } 
    }

    int imageWidth() const { return m_bgImage.width(); }
    int imageHeight() const { return m_bgImage.height(); }

    Q_INVOKABLE void loadImage(const QString& path) {
        m_bgImage = QImage(path);
        
        // NEW: Tell QML the image is loaded so it can resize the window dynamically
        emit imageLoaded(); 
        
        updateScale();
        m_selectionRect = QRectF(0, 0, m_bgImage.width(), m_bgImage.height());
        m_annotations.clear();
        m_redoStack.clear();
        m_selectedIndex = -1;
        emit selectionChanged();
        update();
    }

    Q_INVOKABLE void selectAll() {
        if (m_bgImage.isNull()) return;
        m_selectionRect = QRectF(0, 0, m_bgImage.width(), m_bgImage.height());
        update();
    }
    
    Q_INVOKABLE void pasteFromClipboard() {
        if (m_bgImage.isNull()) return;
        const QClipboard *clipboard = QGuiApplication::clipboard();
        const QMimeData *mimeData = clipboard->mimeData();
        double cx = m_bgImage.width() / 2.0;
        double cy = m_bgImage.height() / 2.0;

        if (mimeData->hasImage()) {
            QImage img = qvariant_cast<QImage>(mimeData->imageData());
            if (!img.isNull()) {
                double max_w = m_bgImage.width() * 0.7;
                double max_h = m_bgImage.height() * 0.7;
                if (img.width() > max_w || img.height() > max_h) {
                    img = img.scaled(max_w, max_h, Qt::KeepAspectRatio, Qt::SmoothTransformation);
                }
                AnnItem item;
                item.type = 6;
                item.image = img;
                item.rect = QRectF(cx - img.width()/2.0, cy - img.height()/2.0, img.width(), img.height());
                m_redoStack.clear();
                m_annotations.append(item);
                setAnnMode(6);
                m_selectedIndex = m_annotations.size() - 1;
                emit selectionChanged();
                emit rotationChanged();
                update();
            }
        } else if (mimeData->hasText()) {
            QString text = mimeData->text().trimmed();
            if (!text.isEmpty()) {
                AnnItem item;
                item.type = 5;
                item.color = m_color;
                item.width = m_textSize;
                item.text = text;
                QFont font("sans-serif");
                font.setPixelSize(qMax(1, qRound(m_textSize)));
                font.setBold(true);
                QFontMetricsF fm(font);
                QRectF br = fm.boundingRect(text);
                item.rect = QRectF(cx - br.width()/2.0, cy - br.height()/2.0, br.width(), br.height());
                m_redoStack.clear();
                m_annotations.append(item);
                setAnnMode(6);
                m_selectedIndex = m_annotations.size() - 1;
                emit selectionChanged();
                emit rotationChanged();
                emit textSizeChanged();
                update();
            }
        }
    }

    Q_INVOKABLE void addTextAnnotation(double x, double y, const QString& text) {
        AnnItem item;
        item.type = 5;
        item.color = m_color;
        item.width = m_textSize;
        item.text = text;
        QFont font("sans-serif");
        font.setPixelSize(qMax(1, qRound(m_textSize)));
        font.setBold(true);
        QFontMetricsF fm(font);
        QRectF br = fm.boundingRect(text);
        item.rect = QRectF(x, y, br.width(), br.height()); 
        m_annotations.append(item);
        m_redoStack.clear();
        update();
    }

    Q_INVOKABLE void processFinalImage(bool saveToDisk) {
        m_selectedIndex = -1; 
        emit selectionChanged();
        QImage target = m_bgImage.copy();
        QPainter p(&target);
        p.setRenderHint(QPainter::Antialiasing, true);
        p.setRenderHint(QPainter::SmoothPixmapTransform, true);
        drawAnnotations(&p);
        p.end();

        QImage cropped = target.copy(m_selectionRect.toRect());
        QString tempPath = QDir::tempPath() + "/qscreen_final.png";
        cropped.save(tempPath, "PNG");

        if (saveToDisk) {
            QString outPath = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation) + 
                              "/screenshot-" + QDateTime::currentDateTime().toString("yyyy-MM-dd_HH-mm-ss") + ".png";
            QFile::copy(tempPath, outPath);
            QProcess::execute("sh", {"-c", QString("wl-copy -t image/png < \"%1\"").arg(outPath)});
            QProcess::execute("notify-send", {"Screenshot Captured", "Screenshot saved and copied."});
        } else {
            QProcess::execute("sh", {"-c", QString("wl-copy -t image/png < \"%1\"").arg(tempPath)});
            QProcess::execute("notify-send", {"Screenshot Captured", "Image is on your clipboard."});
        }
    }

    Q_INVOKABLE void deleteSelected() {
        if (m_selectedIndex >= 0 && m_selectedIndex < m_annotations.size()) {
            m_redoStack.append(m_annotations.takeAt(m_selectedIndex));
            m_selectedIndex = -1;
            emit selectionChanged();
            update();
        }
    }

    Q_INVOKABLE void undo() {
        if (!m_annotations.isEmpty()) {
            m_selectedIndex = -1;
            m_redoStack.append(m_annotations.takeLast());
            emit selectionChanged();
            update();
        }
    }
    
    Q_INVOKABLE void redo() {
        if (!m_redoStack.isEmpty()) {
            m_selectedIndex = -1;
            m_annotations.append(m_redoStack.takeLast());
            emit selectionChanged();
            update();
        }
    }

    Q_INVOKABLE QPointF mapToScreen(double ix, double iy) { return QPointF(ix * m_scale + m_offsetX, iy * m_scale + m_offsetY); }
    Q_INVOKABLE QPointF mapToScreenSize(double iw, double ih) { return QPointF(iw * m_scale, ih * m_scale); }

    void paint(QPainter *painter) override {
        if (m_bgImage.isNull()) return;
        updateScale();
        
        if (m_isDragging) {
            painter->setRenderHint(QPainter::Antialiasing, false);
            painter->setRenderHint(QPainter::SmoothPixmapTransform, false);
        } else {
            painter->setRenderHint(QPainter::Antialiasing, true);
            painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
        }
        
        QRectF targetRect(m_offsetX, m_offsetY, m_bgImage.width() * m_scale, m_bgImage.height() * m_scale);
        painter->drawImage(targetRect, m_bgImage);

        painter->save();
        painter->translate(m_offsetX, m_offsetY);
        painter->scale(m_scale, m_scale);

        bool isFullScreen = (m_selectionRect.width() >= m_bgImage.width() - 1 && m_selectionRect.height() >= m_bgImage.height() - 1);
        if (!isFullScreen && m_selectionRect.isValid() && m_selectionRect.width() > 10) {
            QPainterPath path;
            path.addRect(QRectF(0, 0, m_bgImage.width(), m_bgImage.height()));
            path.addRoundedRect(m_selectionRect, 8, 8);
            painter->setBrush(QColor(0, 0, 0, 150));
            painter->setPen(Qt::NoPen);
            painter->drawPath(path); 

            painter->setPen(QPen(Qt::white, 2 / m_scale));
            painter->setBrush(Qt::NoBrush);
            painter->drawRoundedRect(m_selectionRect, 8, 8);
        }

        drawAnnotations(painter);

        if (m_activeMode == 4 && m_annMode == 6 && m_selectedIndex >= 0 && m_selectedIndex < m_annotations.size()) {
            const AnnItem& item = m_annotations[m_selectedIndex];
            QRectF b = getBounds(item);
            QPointF cx = b.center();
            painter->save();
            painter->translate(cx);
            painter->rotate(item.rotation * 180.0 / M_PI);
            painter->translate(-cx);
            painter->setPen(QPen(QColor(50, 150, 255, 200), 2 / m_scale, Qt::DashLine));
            painter->setBrush(Qt::NoBrush);
            painter->drawRect(b);
            double handleRadius = 5.0 / m_scale;
            double handleSize = 10.0 / m_scale;
            double stickLen = 25.0 / m_scale;
            painter->setPen(QPen(QColor(50, 150, 255), 2 / m_scale));
            painter->drawLine(QPointF(cx.x(), b.top()), QPointF(cx.x(), b.top() - stickLen));
            painter->setBrush(Qt::white);
            painter->drawEllipse(QPointF(cx.x(), b.top() - stickLen), handleRadius + 1/m_scale, handleRadius + 1/m_scale);
            painter->setBrush(Qt::white);
            painter->drawRect(QRectF(b.right() - handleRadius, b.bottom() - handleRadius, handleSize, handleSize));
            painter->setBrush(Qt::red);
            painter->setPen(Qt::NoPen);
            QRectF delRect(b.right() - handleRadius, b.top() - handleRadius, handleSize, handleSize);
            painter->drawRect(delRect);
            painter->setPen(QPen(Qt::white, 1.5 / m_scale));
            painter->drawLine(delRect.topLeft() + QPointF(2/m_scale, 2/m_scale), delRect.bottomRight() - QPointF(2/m_scale, 2/m_scale));
            painter->drawLine(delRect.topRight() + QPointF(-2/m_scale, 2/m_scale), delRect.bottomLeft() + QPointF(2/m_scale, -2/m_scale));
            painter->restore();
        }

        painter->restore();

        if (m_activeMode == 3 && m_isHovering) {
            QPointF imgPos = mapToImage(m_hoverPos);
            QColor pixel = m_bgImage.pixelColor(imgPos.toPoint());
            painter->setBrush(pixel);
            painter->setPen(QPen(Qt::white, 2));
            painter->drawEllipse(m_hoverPos, 40, 40);
            painter->setPen(Qt::black);
            painter->drawText(m_hoverPos + QPointF(10, 50), pixel.name().toUpper());
            painter->setPen(Qt::white);
            painter->drawText(m_hoverPos + QPointF(9, 49), pixel.name().toUpper());
        }
    }

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override {
        QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);
        updateScale();
    }

    void mousePressEvent(QMouseEvent *event) override {
        QPointF imgPos = mapToImage(event->pos());
        m_dragStart = imgPos;
        m_isDragging = false;
        
        if (m_activeMode == 0 || m_activeMode == 4) setInteracting(true);
        
        if (m_activeMode == 4) {
            if (m_annMode == 6) { 
                m_dragAction = 0;
                double stickLen = 25.0 / m_scale;
                double hitRadius = 15.0 / m_scale;
                if (m_selectedIndex >= 0 && m_selectedIndex < m_annotations.size()) {
                    AnnItem& item = m_annotations[m_selectedIndex];
                    QRectF b = getBounds(item);
                    QPointF cx = b.center();
                    QTransform t;
                    t.translate(cx.x(), cx.y());
                    t.rotateRadians(item.rotation);
                    t.translate(-cx.x(), -cx.y());
                    QPointF localPos = t.inverted().map(imgPos);
                    if (qAbs(localPos.x() - b.right()) < hitRadius && qAbs(localPos.y() - b.top()) < hitRadius) { deleteSelected(); return; }
                    if (QLineF(localPos, QPointF(cx.x(), b.top() - stickLen)).length() < hitRadius) { m_dragAction = 3; return; }
                    if (qAbs(localPos.x() - b.right()) < hitRadius && qAbs(localPos.y() - b.bottom()) < hitRadius) { m_dragAction = 2; return; }
                }

                int oldIndex = m_selectedIndex;
                m_selectedIndex = -1;
                for (int i = m_annotations.size() - 1; i >= 0; --i) {
                    const AnnItem& item = m_annotations[i];
                    QRectF b = getBounds(item);
                    QPointF cx = b.center();
                    QTransform t;
                    t.translate(cx.x(), cx.y());
                    t.rotateRadians(item.rotation);
                    t.translate(-cx.x(), -cx.y());
                    QPointF localPos = t.inverted().map(imgPos);
                    if (b.adjusted(-10, -10, 10, 10).contains(localPos)) {
                        m_selectedIndex = i;
                        m_dragAction = 1; 
                        m_color = item.color; emit colorChanged();
                        if (item.type == 5) { m_textSize = item.width; emit textSizeChanged(); } 
                        else if (item.type != 6) { m_size = item.width; emit sizeChanged(); }
                        m_annotations.append(m_annotations.takeAt(i));
                        m_selectedIndex = m_annotations.size() - 1;
                        break;
                    }
                }
                if (m_selectedIndex != oldIndex) { emit selectionChanged(); emit rotationChanged(); }
                update();
            } else if (m_annMode == 5) { 
                emit textPromptRequested(imgPos.x(), imgPos.y());
            } else { 
                m_redoStack.clear();
                m_selectedIndex = -1;
                emit selectionChanged();
                AnnItem item;
                item.type = m_annMode;
                item.color = m_color;
                item.width = m_size;
                item.rect = QRectF(imgPos, imgPos);
                if (m_annMode == 0 || m_annMode == 3) item.points << imgPos;
                m_annotations.append(item);
            }
        } else if (m_activeMode == 3) { 
            QString hex = m_bgImage.pixelColor(imgPos.toPoint()).name().toUpper();
            QProcess::execute("wl-copy", {hex});
            QProcess::execute("notify-send", {"Color Picked", "Copied " + hex + " to clipboard."});
            emit captureFinished();
        }
    }

    void mouseMoveEvent(QMouseEvent *event) override {
        QPointF imgPos = mapToImage(event->pos());
        m_isDragging = true;
        
        if (m_activeMode == 0) { 
            m_selectionRect = QRectF(m_dragStart, imgPos).normalized();
        } else if (m_activeMode == 3) { 
            m_hoverPos = event->pos();
        } else if (m_activeMode == 4) {
            if (m_annMode == 6 && m_selectedIndex >= 0) {
                AnnItem &item = m_annotations[m_selectedIndex];
                QRectF b = getBounds(item);
                QPointF cx = b.center();
                if (m_dragAction == 1) { 
                    QPointF delta = imgPos - m_dragStart;
                    if (item.type == 0 || item.type == 3) { for (auto& p : item.points) p += delta; } 
                    else { item.rect.translate(delta); }
                    m_dragStart = imgPos;
                } else if (m_dragAction == 3) { 
                    item.rotation = qAtan2(imgPos.y() - cx.y(), imgPos.x() - cx.x()) + M_PI_2;
                    emit rotationChanged();
                } else if (m_dragAction == 2) { 
                    QTransform t; t.translate(cx.x(), cx.y()); t.rotateRadians(item.rotation); t.translate(-cx.x(), -cx.y());
                    QPointF localPos = t.inverted().map(imgPos);
                    double dx = localPos.x() - b.right();
                    double dy = localPos.y() - b.bottom();
                    QPointF oldTopLeftAbs = t.map(b.topLeft());

                    if (item.type == 0 || item.type == 3) {
                        double sx = (b.width() + dx) / qMax(1.0, b.width());
                        double sy = (b.height() + dy) / qMax(1.0, b.height());
                        for (auto& p : item.points) {
                            p.setX(b.left() + (p.x() - b.left()) * sx);
                            p.setY(b.top() + (p.y() - b.top()) * sy);
                        }
                    } else if (item.type == 5) {
                        item.width = qMax(4.0, item.width + dx * 0.5); 
                        QFont font("sans-serif"); font.setPixelSize(qMax(1, qRound(item.width))); font.setBold(true);
                        QFontMetricsF fm(font); QRectF br = fm.boundingRect(item.text);
                        item.rect.setWidth(br.width()); item.rect.setHeight(br.height());
                        m_textSize = item.width; emit textSizeChanged();
                    } else if (item.type == 6) {
                        double ratio = item.image.width() / (double)item.image.height();
                        if (qAbs(dx) > qAbs(dy)) {
                            item.rect.setWidth(qMax(10.0, item.rect.width() + dx));
                            item.rect.setHeight(item.rect.width() / ratio);
                        } else {
                            item.rect.setHeight(qMax(10.0, item.rect.height() + dy));
                            item.rect.setWidth(item.rect.height() * ratio);
                        }
                    } else {
                        item.rect.setRight(item.rect.right() + dx);
                        item.rect.setBottom(item.rect.bottom() + dy);
                    }
                    QRectF newB = getBounds(item);
                    QPointF newCenter = newB.center();
                    QTransform tNew; tNew.translate(newCenter.x(), newCenter.y()); tNew.rotateRadians(item.rotation); tNew.translate(-newCenter.x(), -newCenter.y());
                    QPointF newTopLeftAbs = tNew.map(newB.topLeft());
                    QPointF correction = oldTopLeftAbs - newTopLeftAbs;
                    if (item.type == 0 || item.type == 3) { for (auto& p : item.points) p += correction; } 
                    else { item.rect.translate(correction); }
                }
            } else if (!m_annotations.isEmpty() && m_annMode != 5 && m_annMode != 6) { 
                AnnItem &item = m_annotations.last();
                if (m_annMode == 0) item.points << imgPos; 
                else if (m_annMode == 3) { item.points.clear(); item.points << m_dragStart << imgPos; } 
                else item.rect = QRectF(m_dragStart, imgPos).normalized(); 
            }
        }
        update();
    }

    void mouseReleaseEvent(QMouseEvent *event) override {
        Q_UNUSED(event);
        if (m_activeMode == 0 && m_isDragging) emit regionSelected();
        m_isDragging = false;
        m_dragAction = 0;
        setInteracting(false);
        update();
    }

    void hoverMoveEvent(QHoverEvent *event) override {
        m_hoverPos = event->position();
        m_isHovering = true;
        if (m_activeMode == 3) update();
    }

signals:
    void modeChanged();
    void annModeChanged();
    void colorChanged();
    void sizeChanged();
    void textSizeChanged();
    void scaleChanged();
    void captureFinished();
    void regionSelected();
    void textPromptRequested(double imgX, double imgY);
    void isInteractingChanged();
    void selectionChanged();
    void rotationChanged();
    
    // NEW SIGNAL: Notifies QML when the true dimensions of the image have successfully loaded
    void imageLoaded();

private:
    void updateScale() {
        if (m_bgImage.isNull() || boundingRect().isEmpty()) return;
        m_scale = qMin(boundingRect().width() / m_bgImage.width(), boundingRect().height() / m_bgImage.height());
        m_offsetX = (boundingRect().width() - m_bgImage.width() * m_scale) / 2.0;
        m_offsetY = (boundingRect().height() - m_bgImage.height() * m_scale) / 2.0;
        emit scaleChanged();
    }

    QPointF mapToImage(const QPointF& screenPos) {
        double ix = (screenPos.x() - m_offsetX) / m_scale;
        double iy = (screenPos.y() - m_offsetY) / m_scale;
        return QPointF(qBound(0.0, ix, (double)m_bgImage.width() - 1), qBound(0.0, iy, (double)m_bgImage.height() - 1));
    }

    QRectF getBounds(const AnnItem& item) {
        if (item.type == 0 || item.type == 3) {
            if (item.points.isEmpty()) return QRectF();
            double x1 = item.points[0].x(), x2 = x1, y1 = item.points[0].y(), y2 = y1;
            for (const auto& p : item.points) {
                if (p.x() < x1) { x1 = p.x(); }
                if (p.x() > x2) { x2 = p.x(); }
                if (p.y() < y1) { y1 = p.y(); }
                if (p.y() > y2) { y2 = p.y(); }
            }
            return QRectF(x1, y1, x2 - x1, y2 - y1).adjusted(-10, -10, 10, 10);
        }
        if (item.type == 5) return item.rect.adjusted(-5, -5, 5, 5); 
        return item.rect;
    }

    void drawAnnotations(QPainter *painter) {
        for (const auto& item : m_annotations) {
            painter->save();
            QRectF b = getBounds(item);
            QPointF cx = b.center();
            painter->translate(cx);
            painter->rotate(item.rotation * 180.0 / M_PI);
            painter->translate(-cx);

            painter->setPen(QPen(item.color, item.width, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
            painter->setBrush(Qt::NoBrush);
            
            if (item.type == 0) painter->drawPolyline(item.points.data(), item.points.size()); 
            else if (item.type == 1) painter->drawRect(item.rect); 
            else if (item.type == 2) painter->drawEllipse(item.rect); 
            else if (item.type == 3 && item.points.size() == 2) {
                painter->drawLine(item.points[0], item.points[1]);
                double angle = qAtan2(item.points[1].y() - item.points[0].y(), item.points[1].x() - item.points[0].x());
                double headSize = item.width * 4.0;
                QPolygonF head;
                head << item.points[1];
                head << item.points[1] - QPointF(qCos(angle - M_PI/6) * headSize, qSin(angle - M_PI/6) * headSize);
                head << item.points[1] - QPointF(qCos(angle + M_PI/6) * headSize, qSin(angle + M_PI/6) * headSize);
                painter->setBrush(item.color);
                painter->drawPolygon(head);
            }
            else if (item.type == 4 && !item.rect.isEmpty()) { 
                AnnItem& mutItem = const_cast<AnnItem&>(item);
                QRectF r = mutItem.rect.normalized();
                if (mutItem.image.isNull() || mutItem.cachedRect != r || mutItem.cachedWidth != mutItem.width) {
                    QImage sub = m_bgImage.copy(r.toRect());
                    int ps = std::max(2.0, mutItem.width);
                    QImage small = sub.scaled(sub.width()/ps, sub.height()/ps, Qt::IgnoreAspectRatio, Qt::FastTransformation);
                    mutItem.image = small.scaled(sub.width(), sub.height(), Qt::IgnoreAspectRatio, Qt::FastTransformation);
                    mutItem.cachedRect = r;
                    mutItem.cachedWidth = mutItem.width;
                }
                painter->drawImage(mutItem.rect.topLeft(), mutItem.image);
            }
            else if (item.type == 5) {
                QFont font("sans-serif");
                font.setPixelSize(qMax(1, qRound(item.width)));
                font.setBold(true);
                painter->setFont(font);
                painter->setPen(item.color);
                painter->drawText(item.rect.topLeft() + QPointF(0, QFontMetricsF(font).ascent()), item.text);
            } 
            else if (item.type == 6) {
                painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
                painter->drawImage(item.rect, item.image);
            }
            painter->restore();
        }
    }

    QImage m_bgImage;
    QRectF m_selectionRect;
    QPointF m_dragStart, m_hoverPos;
    bool m_isHovering = false, m_isDragging = false;
    double m_scale = 1.0, m_offsetX = 0.0, m_offsetY = 0.0;
    int m_activeMode = 0; 
    int m_annMode = 0; 
    int m_selectedIndex = -1;
    int m_dragAction = 0; 
    bool m_isInteracting = false;
    QColor m_color = Qt::red;
    double m_size = 6.0;
    double m_textSize = 32.0;
    QList<AnnItem> m_annotations;
    QList<AnnItem> m_redoStack;
};