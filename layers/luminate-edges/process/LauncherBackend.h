#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <QDBusContext>
#include <QMetaType>
#include <QDBusArgument>

struct SearchResult {
    uint type;
    QString title;
    QString desc;
    QString icon;
    QString payload;
    int score;
};
Q_DECLARE_METATYPE(SearchResult)

inline QDBusArgument &operator<<(QDBusArgument &argument, const SearchResult &res) {
    argument.beginStructure();
    argument << res.type << res.title << res.desc << res.icon << res.payload << res.score;
    argument.endStructure();
    return argument;
}

inline const QDBusArgument &operator>>(const QDBusArgument &argument, SearchResult &res) {
    argument.beginStructure();
    argument >> res.type >> res.title >> res.desc >> res.icon >> res.payload >> res.score;
    argument.endStructure();
    return argument;
}

class LauncherBackend : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.meismeric.luminate.widget") 

    Q_PROPERTY(QVariantList results READ results NOTIFY resultsChanged)
    Q_PROPERTY(int currentMode READ currentMode NOTIFY modeChanged)

public:
    explicit LauncherBackend(const QString& widgetName, QObject *parent = nullptr);

    QVariantList results() const { return m_results; }
    int currentMode() const { return m_currentMode; }

    Q_INVOKABLE void query(const QString& text);
    Q_INVOKABLE void activateResult(int index);
    Q_INVOKABLE void setMode(int mode); 
    Q_INVOKABLE void deleteClipboardItem(int index);
    Q_INVOKABLE void clearState();

signals:
    void resultsChanged();
    void modeChanged();

private:
    void launchApp(const QString& desktopId);

    QVariantList m_results;
    int m_currentMode = 0; 
};