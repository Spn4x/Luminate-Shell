#pragma once

#include <QObject>
#include <QJsonArray>
#include <QJsonObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>

class Storage : public QObject {
    Q_OBJECT
public:
    explicit Storage(QObject *parent = nullptr);
    ~Storage();

    Q_INVOKABLE void saveLayout(const QJsonArray &layout);
    Q_INVOKABLE QJsonArray loadLayout();

    Q_INVOKABLE void saveLockscreenLayout(const QJsonArray &layout);
    Q_INVOKABLE QJsonArray loadLockscreenLayout();

private:
    QSqlDatabase m_db;
    void initDatabase();
    void safelyAddColumn(const QString &table, const QString &column, const QString &typeAndDefault);
};