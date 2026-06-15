#include <QCoreApplication>
#include <QProcess>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QStringList>
#include <QDir>
#include <QFileInfo>
#include <QList>
#include <iostream>
#include <csignal>

QList<QProcess*> g_processes;

// Catch Ctrl+C to cleanly kill all children
void cleanupHandler(int sig) {
    std::cout << "\n[Luminate] Shutting down session..." << std::endl;
    for (QProcess *p : g_processes) {
        if (p->state() == QProcess::Running) {
            p->terminate();
            if (!p->waitForFinished(500)) {
                p->kill();
            }
        }
        delete p;
    }
    g_processes.clear();
    std::exit(sig);
}

void printHelp() {
    std::cout << "Luminate Shell Session Manager\n"
              << "Usage: luminate [OPTIONS]\n\n"
              << "If run without arguments, it will start the full desktop session.\n\n"
              << "Desktop / Lockscreen (SurfaceDesk):\n"
              << "  -w, --wallpaper      Toggle Wallpaper Selection Mode\n"
              << "  -e, --edit           Toggle Desktop Edit Mode\n"
              << "  -el, --edit-lock     Toggle Lockscreen Edit Mode\n"
              << "  -l, --lock           Lock the screen\n\n"
              << "Shell UI:\n"
              << "  -s, --screenshot     Trigger Screenshot Flow\n"
              << "  -r, --launcher       Trigger App/Search Launcher\n"
              << "  -t, --thinkfan       Trigger Thinkfan Dashboard\n\n" // ADDED
              << "Media Controls:\n"
              << "  -p, --play-pause     Toggle Media Play/Pause\n"
              << "  -n, --next           Next Track\n"
              << "  -b, --prev           Previous Track\n"
              << std::endl;
}

// Smart path resolution: Looks in the local 'build' tree first, falls back to system PATH.
QString resolveBinary(const QString &appName, const QString &buildRelativePath) {
    QString appDir = QCoreApplication::applicationDirPath();
    QString localPath = QDir::cleanPath(appDir + "/" + buildRelativePath + "/" + appName);
    if (QFileInfo::exists(localPath)) {
        return localPath; 
    }
    return appName; 
}

void spawnProcess(const QString &executable) {
    QProcess *p = new QProcess();
    p->setProcessChannelMode(QProcess::ForwardedChannels); 
    
    std::cout << "[Luminate] Spawning: " << executable.toStdString() << std::endl;
    p->start(executable);
    
    if (p->waitForStarted()) {
        g_processes.append(p);
    } else {
        std::cerr << "[!] Failed to spawn: " << executable.toStdString() << std::endl;
        delete p;
    }
}

void startFullSession() {
    std::signal(SIGINT, cleanupHandler);
    std::signal(SIGTERM, cleanupHandler);

    std::cout << "==========================================\n";
    std::cout << "        Starting Luminate Session         \n";
    std::cout << "==========================================\n";

    // Spawn Background Daemons
    spawnProcess(resolveBinary("luminate-privacyd", "daemons"));
    spawnProcess(resolveBinary("luminate-insightd", "daemons"));
    spawnProcess(resolveBinary("luminate-notifyd", "daemons"));
    spawnProcess(resolveBinary("luminate-widgetd", "daemons"));
    spawnProcess(resolveBinary("luminate-osdd", "daemons"));
    spawnProcess(resolveBinary("luminate-mediad", "daemons"));
    spawnProcess(resolveBinary("luminate-launcherd", "daemons"));

    // Spawn Visual Shells
    spawnProcess(resolveBinary("luminate-surfacedesk", "../layers/surfacedesk-qml"));
    spawnProcess(resolveBinary("luminate-edges", "../layers/luminate-edges/src"));

    std::cout << "==========================================\n";
    std::cout << "Session running. Press Ctrl+C to stop.\n";
    std::cout << "==========================================\n";
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    QStringList args = app.arguments();

    // If no arguments, we are the SESSION MANAGER
    if (args.size() == 1) {
        startFullSession();
        return app.exec(); 
    }

    QString arg = args[1];

    if (arg == "-h" || arg == "--help") {
        printHelp();
        return 0;
    }

    if (arg == "-w" || arg == "--wallpaper" || 
        arg == "-e" || arg == "--edit" || 
        arg == "-el" || arg == "--edit-lock" || 
        arg == "-l" || arg == "--lock") {
        
        QDBusInterface iface("com.meismeric.SurfaceDesk", "/com/meismeric/SurfaceDesk", "com.meismeric.SurfaceDesk", QDBusConnection::sessionBus());
        if (!iface.isValid()) { std::cerr << "Error: SurfaceDesk is not running." << std::endl; return 1; }
        
        if (arg == "-w" || arg == "--wallpaper") iface.call("ToggleWallpaperMode");
        if (arg == "-e" || arg == "--edit") iface.call("ToggleEditMode");
        if (arg == "-el" || arg == "--edit-lock") iface.call("ToggleLockscreenEditMode");
        if (arg == "-l" || arg == "--lock") iface.call("setLocked", true);
    }
    // MODIFIED THIS BLOCK TO CATCH -t
    else if (arg == "-s" || arg == "--screenshot" || 
             arg == "-r" || arg == "--launcher" ||
             arg == "-t" || arg == "--thinkfan") {
        
        QDBusInterface iface("com.meismeric.luminate.UI", "/com/meismeric/luminate/UI", "com.meismeric.luminate.UI", QDBusConnection::sessionBus());
        if (!iface.isValid()) { std::cerr << "Error: Luminate Shell UI is not running." << std::endl; return 1; }
        
        if (arg == "-s" || arg == "--screenshot") iface.call("triggerScreenshotFlow");
        if (arg == "-r" || arg == "--launcher") iface.call("triggerLauncherFlow");
        if (arg == "-t" || arg == "--thinkfan") iface.call("triggerFanFlow"); // ADDED
    }
    else if (arg == "-p" || arg == "--play-pause" || 
             arg == "-n" || arg == "--next" || 
             arg == "-b" || arg == "--prev") {
             
        QDBusInterface iface("com.meismeric.luminate.MediaManager", "/com/meismeric/luminate/MediaManager", "com.meismeric.luminate.MediaManager", QDBusConnection::sessionBus());
        if (!iface.isValid()) { std::cerr << "Error: Media Daemon is not running." << std::endl; return 1; }
        
        if (arg == "-p" || arg == "--play-pause") iface.call("mediaPlayPause");
        if (arg == "-n" || arg == "--next") iface.call("mediaNext");
        if (arg == "-b" || arg == "--prev") iface.call("mediaPrev");
    }
    else {
        std::cerr << "Unknown argument: " << arg.toStdString() << "\n";
        printHelp();
        return 1;
    }

    return 0;
}