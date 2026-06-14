#include <QCoreApplication>
#include <QObject>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QTimer>
#include <QDebug>
#include <thread>
#include <mutex>
#include <pipewire/pipewire.h>

struct PwStream {
    uint32_t id;
    uint32_t pid;
    QString name;
    int type; // 0 = mic, 1 = cam
};

class PrivacyDaemon : public QObject {
    Q_OBJECT
public:
    PrivacyDaemon() {
        pw_init(nullptr, nullptr);
        m_uiIface = new QDBusInterface("com.meismeric.luminate.UI", "/com/meismeric/luminate/UI", "com.meismeric.luminate.UI", QDBusConnection::sessionBus(), this);
        
        m_pwThread = std::thread([this]() { runPipewire(); });
        m_pwThread.detach();

        m_updateTimer = new QTimer(this);
        m_updateTimer->setSingleShot(true);
        connect(m_updateTimer, &QTimer::timeout, this, &PrivacyDaemon::sendUpdate);
    }

public slots:
    void triggerUpdate() { m_updateTimer->start(100); }

private:
    QDBusInterface *m_uiIface;
    std::thread m_pwThread;
    QTimer *m_updateTimer;
    std::vector<PwStream> m_streams;
    std::mutex m_mutex;

    void sendUpdate() {
        std::lock_guard<std::mutex> lock(m_mutex);
        QJsonArray arr;
        for (const auto& s : m_streams) {
            QJsonObject obj;
            obj["id"] = (qint64)s.id;
            obj["pid"] = (qint64)s.pid;
            obj["name"] = s.name;
            obj["type"] = s.type;
            arr.append(obj);
        }
        QJsonDocument doc(arr);
        m_uiIface->asyncCall("SetPrivacyStatus", QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
    }

    void runPipewire() {
        struct pw_main_loop *loop = pw_main_loop_new(nullptr);
        struct pw_context *context = pw_context_new(pw_main_loop_get_loop(loop), nullptr, 0);
        struct pw_core *core = pw_context_connect(context, nullptr, 0);
        struct pw_registry *registry = pw_core_get_registry(core, PW_VERSION_REGISTRY, 0);

        static const struct pw_registry_events registry_events = {
            PW_VERSION_REGISTRY_EVENTS,
            .global = [](void *data, uint32_t id, uint32_t, const char *type, uint32_t, const struct spa_dict *props) {
                if (props && strcmp(type, PW_TYPE_INTERFACE_Node) == 0) {
                    const char *media_class = spa_dict_lookup(props, "media.class");
                    if (!media_class) return;
                    int stream_type = -1;
                    if (strcmp(media_class, "Stream/Input/Audio") == 0) stream_type = 0;
                    else if (strcmp(media_class, "Stream/Input/Video") == 0) stream_type = 1;

                    if (stream_type != -1) {
                        PrivacyDaemon* self = static_cast<PrivacyDaemon*>(data);
                        std::lock_guard<std::mutex> lock(self->m_mutex);
                        for (const auto& s : self->m_streams) if (s.id == id) return;

                        const char *app_name = spa_dict_lookup(props, "application.name");
                        if (!app_name) app_name = spa_dict_lookup(props, "node.name");
                        const char *pid_str = spa_dict_lookup(props, "application.process.id");

                        self->m_streams.push_back({id, pid_str ? (uint32_t)atoi(pid_str) : 0, app_name ? QString::fromUtf8(app_name) : "Unknown", stream_type});
                        QMetaObject::invokeMethod(self, "triggerUpdate", Qt::QueuedConnection);
                    }
                }
            },
            .global_remove = [](void *data, uint32_t id) {
                PrivacyDaemon* self = static_cast<PrivacyDaemon*>(data);
                std::lock_guard<std::mutex> lock(self->m_mutex);
                for (auto it = self->m_streams.begin(); it != self->m_streams.end(); ++it) {
                    if (it->id == id) {
                        self->m_streams.erase(it);
                        QMetaObject::invokeMethod(self, "triggerUpdate", Qt::QueuedConnection);
                        break;
                    }
                }
            }
        };

        struct spa_hook registry_listener;
        if (registry) {
            pw_registry_add_listener(registry, &registry_listener, &registry_events, this);
            pw_main_loop_run(loop);
        }
        if (core) pw_core_disconnect(core);
        if (context) pw_context_destroy(context);
        pw_main_loop_destroy(loop);
    }
};

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    PrivacyDaemon daemon;
    qDebug() << "luminate-privacyd: Pipewire hardware monitor running.";
    return app.exec();
}
#include "privacyd.moc"