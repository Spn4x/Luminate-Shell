#include <QCoreApplication>
#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem> 
#include <QScreen>
#include <QQmlEngine>
#include <QQmlContext>
#include <LayerShellQt/Window>
#include <QList>
#include <QMap>
#include <QRegion>
#include <QRect>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QTextStream>
#include <QDebug>
#include "WallpaperBackend.h"
#include "Storage.h"

static QMap<QScreen*, QQuickView*> s_windows;
static QMap<QScreen*, QQuickView*> s_lockScreenWindows;

static WallpaperBackend* s_backend = nullptr;
static Storage* s_storage = nullptr;
static QQmlEngine* s_engine = nullptr;

void createWallpaperWindow(QScreen* screen) {
    if (s_windows.contains(screen)) return;

    auto* view = new QQuickView(s_engine, nullptr);
    view->setScreen(screen);
    view->setColor(Qt::transparent);
    view->setResizeMode(QQuickView::SizeRootObjectToView);

    auto* layerWindow = LayerShellQt::Window::get(view);
    if (layerWindow) {
        layerWindow->setLayer(LayerShellQt::Window::LayerBottom);
        layerWindow->setScope(QStringLiteral("wallpaper"));
        layerWindow->setExclusiveZone(-1);
        
        if (s_backend && s_backend->isEditing()) {
            layerWindow->setLayer(LayerShellQt::Window::LayerTop);
            layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
        } else {
            layerWindow->setLayer(LayerShellQt::Window::LayerBottom);
            layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
        }

        layerWindow->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorTop) | 
                               LayerShellQt::Window::AnchorBottom | 
                               LayerShellQt::Window::AnchorLeft | 
                               LayerShellQt::Window::AnchorRight);
    }

    view->rootContext()->setContextProperty("wallpaperBackend", s_backend);
    view->rootContext()->setContextProperty("desktopStorage", s_storage);
    view->setSource(QUrl(QStringLiteral("qrc:/ui/Main.qml")));
    view->setGeometry(screen->geometry());
    view->show();

    s_windows.insert(screen, view);

    if (s_backend && layerWindow) {
        QObject::connect(s_backend, &WallpaperBackend::isEditingChanged, view, [layerWindow]() {
            if (s_backend->isEditing()) {
                layerWindow->setLayer(LayerShellQt::Window::LayerTop);
                layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
            } else {
                layerWindow->setLayer(LayerShellQt::Window::LayerBottom);
                layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
            }
        });
    }
}

void createLockScreenWindow(QScreen* screen) {
    if (s_lockScreenWindows.contains(screen)) return;

    auto* view = new QQuickView(s_engine, nullptr);
    view->setScreen(screen);
    view->setColor(Qt::transparent);
    view->setResizeMode(QQuickView::SizeRootObjectToView);

    if (auto* layerWindow = LayerShellQt::Window::get(view)) {
        layerWindow->setScope(QStringLiteral("wallpaper-lockscreen"));
        layerWindow->setExclusiveZone(-1);
        
        if (s_backend->isLocked()) {
            layerWindow->setLayer(LayerShellQt::Window::LayerOverlay);
            layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityExclusive);
        } else if (s_backend->isEditingLockscreen()) {
            layerWindow->setLayer(LayerShellQt::Window::LayerTop);
            layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
        }

        layerWindow->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorTop) | 
                               LayerShellQt::Window::AnchorBottom | 
                               LayerShellQt::Window::AnchorLeft | 
                               LayerShellQt::Window::AnchorRight);
    }

    view->rootContext()->setContextProperty("wallpaperBackend", s_backend);
    view->rootContext()->setContextProperty("desktopStorage", s_storage);
    view->setSource(QUrl(QStringLiteral("qrc:/ui/scenes/LockScreen.qml")));
    view->show();

    s_lockScreenWindows.insert(screen, view);

    if (s_backend) {
        QObject::connect(s_backend, &WallpaperBackend::isLockedChanged, view, [view]() {
            if (auto* layerWindow = LayerShellQt::Window::get(view)) {
                if (s_backend->isLocked()) {
                    layerWindow->setLayer(LayerShellQt::Window::LayerOverlay);
                    layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityExclusive);
                } else if (s_backend->isEditingLockscreen()) {
                    layerWindow->setLayer(LayerShellQt::Window::LayerTop);
                    layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
                }
            }
        });
        
        QObject::connect(s_backend, &WallpaperBackend::isEditingLockscreenChanged, view, [view]() {
            if (auto* layerWindow = LayerShellQt::Window::get(view)) {
                if (s_backend->isLocked()) {
                    layerWindow->setLayer(LayerShellQt::Window::LayerOverlay);
                    layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityExclusive);
                } else if (s_backend->isEditingLockscreen()) {
                    layerWindow->setLayer(LayerShellQt::Window::LayerTop);
                    layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
                }
            }
        });
    }
}

void destroyLockScreenWindow(QScreen* screen) {
    if (s_lockScreenWindows.contains(screen)) {
        auto* view = s_lockScreenWindows.take(screen);
        view->close();
        view->deleteLater();
    }
}

int main(int argc, char *argv[]) {
    bool isCliCommand = false;
    for (int i = 1; i < argc; ++i) {
        std::string arg(argv[i]);
        if (arg == "-w" || arg == "-l" || arg == "-e" || arg == "-el") {
            isCliCommand = true;
            break;
        }
    }

    if (isCliCommand) {
        QCoreApplication app(argc, argv);
        QTextStream out(stdout);
        QTextStream err(stderr);
        
        QDBusInterface iface(
            QStringLiteral("com.meismeric.SurfaceDesk"),
            QStringLiteral("/com/meismeric/SurfaceDesk"),
            QStringLiteral("com.meismeric.SurfaceDesk"),
            QDBusConnection::sessionBus()
        );
        
        if (iface.isValid()) {
            QDBusMessage reply;
            if (app.arguments().contains(QStringLiteral("-w"))) {
                reply = iface.call(QStringLiteral("ToggleWallpaperMode"));
            } else if (app.arguments().contains(QStringLiteral("-l"))) {
                reply = iface.call(QStringLiteral("setLocked"), true);
            } else if (app.arguments().contains(QStringLiteral("-e"))) {
                reply = iface.call(QStringLiteral("ToggleEditMode"));
            } else if (app.arguments().contains(QStringLiteral("-el"))) {
                reply = iface.call(QStringLiteral("ToggleLockscreenEditMode"));
            }

            if (reply.type() == QDBusMessage::ErrorMessage) {
                err << "DBus Execution Error: " << reply.errorMessage() << Qt::endl;
            }
        } else {
            err << "Error: SurfaceDesk daemon is not running or DBus interface is unavailable." << Qt::endl;
        }
        return 0;
    }

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("luminate-shell"));
    app.setOrganizationName(QStringLiteral("meismeric"));

    s_engine = new QQmlEngine(&app);
    s_backend = new WallpaperBackend(&app);
    s_storage = new Storage(&app);

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerService(QStringLiteral("com.meismeric.SurfaceDesk"));
    bus.registerObject(
        QStringLiteral("/com/meismeric/SurfaceDesk"),
        QStringLiteral("com.meismeric.SurfaceDesk"),
        s_backend,
        QDBusConnection::ExportAllSlots
    );

    auto updateLayerStates = []() {
        bool locked = s_backend->isLocked();
        bool lockEdit = s_backend->isEditingLockscreen();

        const auto screens = QGuiApplication::screens();
        for (auto* screen : screens) {
            if (locked || lockEdit) {
                createLockScreenWindow(screen);
            } else {
                destroyLockScreenWindow(screen);
            }
        }
    };

    QObject::connect(s_backend, &WallpaperBackend::isEditingChanged, updateLayerStates);
    QObject::connect(s_backend, &WallpaperBackend::isEditingLockscreenChanged, updateLayerStates);
    QObject::connect(s_backend, &WallpaperBackend::isLockedChanged, updateLayerStates);

    const auto screens = QGuiApplication::screens();
    for (auto* screen : screens) {
        createWallpaperWindow(screen);
    }

    QObject::connect(&app, &QGuiApplication::screenAdded, [](QScreen* screen) {
        createWallpaperWindow(screen);
    });

    QObject::connect(&app, &QGuiApplication::screenRemoved, [](QScreen* screen) {
        if (s_windows.contains(screen)) {
            auto* view = s_windows.take(screen);
            view->close();
            view->deleteLater();
        }
        destroyLockScreenWindow(screen);
    });

    return app.exec();
}