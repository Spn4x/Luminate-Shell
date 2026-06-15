#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QWindow>
#include <QSurfaceFormat>
#include <LayerShellQt/Window>
#include <QQuickItem>
#include <QQmlEngine>
#include <QRegion>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QTimer>

#include "../process/NotificationBackend.h" 
#include "../process/ScreenshotCanvas.h"
#include "../process/LauncherBackend.h"
#include "../process/TopbarBackend.h"
#include "../process/SystrayBackend.h"
#include "../process/AudioBackend.h"

int main(int argc, char *argv[])
{
    qputenv("QT_QPA_PLATFORM", "wayland");

    QSurfaceFormat format;
    format.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);

    QGuiApplication app(argc, argv);
    app.setDesktopFileName(QStringLiteral("luminate"));

    NotificationBackend backend;
    LauncherBackend launcherBackend("luminate");
    TopbarBackend topbarBackend;
    SystrayBackend systrayBackend;
    AudioBackend audioBackend;

    qmlRegisterSingletonInstance("Luminate.Shell", 1, 0, "Backend", &backend);
    qmlRegisterSingletonInstance("Luminate.Shell", 1, 0, "Launcher", &launcherBackend);
    qmlRegisterSingletonInstance("Luminate.Shell", 1, 0, "Topbar", &topbarBackend);
    qmlRegisterSingletonInstance("Luminate.Shell", 1, 0, "Systray", &systrayBackend);
    qmlRegisterSingletonInstance("Luminate.Shell", 1, 0, "AudioBackend", &audioBackend);
    qmlRegisterType<ScreenshotCanvas>("Luminate.Shell", 1, 0, "ScreenshotCanvas");

    QQmlApplicationEngine engine;
    engine.addImportPath("qrc:/qml"); 
    engine.load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));
    
    if (engine.rootObjects().isEmpty()) return -1;

    QObject *rootObject = engine.rootObjects().first();
    QWindow *window = qobject_cast<QWindow *>(rootObject);

    QQuickItem* edge = qobject_cast<QQuickItem*>(rootObject->findChild<QObject*>("luminateEdge"));

    if (window && edge) {
        auto updateInputMask = [window, edge, rootObject, &backend]() {
            QRegion mask;
            LayerShellQt::Window *lsWindow = LayerShellQt::Window::get(window);

            static QString lastMode = "";
            QString currentMode = backend.displayMode();
            
            bool needsFocus = (currentMode == "screenshot_edit" || currentMode == "launcher" || currentMode == "wallpaper");
            bool hadFocus = (lastMode == "screenshot_edit" || lastMode == "launcher" || lastMode == "wallpaper");
            
            if (needsFocus && !hadFocus) {
                lsWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityExclusive);
                window->requestActivate();
            } else if (!needsFocus && hadFocus) {
                lsWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
            }
            lastMode = currentMode;

            bool hasFullscreenOverlay = false;
            
            QQuickItem* audioOverlay = qobject_cast<QQuickItem*>(rootObject->findChild<QObject*>("audioMenuOverlay"));
            if (audioOverlay && audioOverlay->isVisible()) hasFullscreenOverlay = true;

            QQuickItem* pulltabMenu = qobject_cast<QQuickItem*>(edge->findChild<QObject*>("pulltabMenu"));
            if (pulltabMenu && pulltabMenu->property("expanded").toBool()) hasFullscreenOverlay = true;

            if (hasFullscreenOverlay) {
                mask += QRegion(0, 0, window->width(), window->height());
            } else {
                QQuickItem* barBg = qobject_cast<QQuickItem*>(edge->findChild<QObject*>("barBg"));
                if (barBg && barBg->opacity() > 0.01) {
                    QRectF barRect = barBg->mapRectToScene(QRectF(0, 0, barBg->width(), barBg->height()));
                    if (barRect.width() > 0 && barRect.height() > 0) {
                        mask += QRegion(barRect.x(), barRect.y(), barRect.width(), barRect.height());
                    }
                }
            }

            if (mask.isEmpty()) {
                window->setMask(QRegion(0, 0, 1, 1));
            } else {
                window->setMask(mask);
            }
        };

        QObject::connect(window, &QWindow::widthChanged, window, updateInputMask);
        QObject::connect(window, &QWindow::heightChanged, window, updateInputMask);
        QObject::connect(edge, &QQuickItem::widthChanged, window, updateInputMask);
        QObject::connect(edge, &QQuickItem::heightChanged, window, updateInputMask);
        QObject::connect(edge, &QQuickItem::xChanged, window, updateInputMask);
        QObject::connect(edge, &QQuickItem::yChanged, window, updateInputMask);

        QQuickItem* barBg = qobject_cast<QQuickItem*>(edge->findChild<QObject*>("barBg"));
        if (barBg) {
            QObject::connect(barBg, &QQuickItem::widthChanged, window, updateInputMask);
            QObject::connect(barBg, &QQuickItem::heightChanged, window, updateInputMask);
            QObject::connect(barBg, &QQuickItem::xChanged, window, updateInputMask);
            QObject::connect(barBg, &QQuickItem::yChanged, window, updateInputMask);
        }

        QQuickItem* pulltabMenu = qobject_cast<QQuickItem*>(edge->findChild<QObject*>("pulltabMenu"));
        if (pulltabMenu) {
            QObject::connect(pulltabMenu, &QQuickItem::heightChanged, window, updateInputMask);
        }

        QQuickItem* audioOverlay = qobject_cast<QQuickItem*>(rootObject->findChild<QObject*>("audioMenuOverlay"));
        if (audioOverlay) {
            QObject::connect(audioOverlay, &QQuickItem::visibleChanged, window, updateInputMask);
        }

        QObject::connect(&backend, &NotificationBackend::displayModeChanged, window, updateInputMask);
        
        updateInputMask();

        LayerShellQt::Window *lsWindow = LayerShellQt::Window::get(window);
        lsWindow->setLayer(LayerShellQt::Window::LayerOverlay);
        lsWindow->setAnchors(static_cast<LayerShellQt::Window::Anchors>(
            LayerShellQt::Window::AnchorTop | 
            LayerShellQt::Window::AnchorBottom | 
            LayerShellQt::Window::AnchorLeft | 
            LayerShellQt::Window::AnchorRight
        ));
        lsWindow->setExclusiveZone(0);
        lsWindow->setMargins(QMargins(0, 0, 0, 0)); 
        window->setVisible(true);

        QTimer::singleShot(150, window, updateInputMask);
    }

    return app.exec();
}