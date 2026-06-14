#include "Storage.h"
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QSqlError>

Storage::Storage(QObject *parent) : QObject(parent) {
    initDatabase();
}

Storage::~Storage() {
    if (m_db.isOpen()) m_db.close();
}

void Storage::initDatabase() {
    qDebug() << "[Storage C++] Starting Database initialization...";
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    if (configDir.isEmpty() || !configDir.contains(QStringLiteral("luminate-shell"))) {
        configDir = QDir::homePath() + QStringLiteral("/.config/luminate-shell");
    }
    QDir().mkpath(configDir);
    QString dbPath = QDir(configDir).absoluteFilePath(QStringLiteral("widgets.db"));

    qDebug() << "[Storage C++] SQLite Database location target:" << dbPath;

    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"));
    m_db.setDatabaseName(dbPath);

    if (!m_db.open()) {
        qWarning() << "[Storage C++] SQL DATABASE ERROR: Failed to open connection!" << m_db.lastError().text();
        return;
    }

    qDebug() << "[Storage C++] SQLite Connection opened successfully!";

    QSqlQuery query(m_db);
    
    // Core desktop widgets table
    if (!query.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS widgets ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, variant INTEGER, grid_x INTEGER, grid_y INTEGER, grid_w INTEGER, grid_h INTEGER, text TEXT, fontSize INTEGER, fontFamily TEXT, useTheme INTEGER, isBold INTEGER, padding INTEGER DEFAULT 0, transparent INTEGER DEFAULT 1, is24h INTEGER DEFAULT 1, dateSize INTEGER DEFAULT 10, offsetX INTEGER DEFAULT 0, offsetY INTEGER DEFAULT 0, timeOpacity REAL DEFAULT 1.0, dateOpacity REAL DEFAULT 0.7, blendAccent INTEGER DEFAULT 1, blendRatio REAL DEFAULT 0.2"
        ")"
    ))) {
        qWarning() << "[Storage C++] Failed to create widgets table:" << query.lastError().text();
    }

    // Core lockscreen widgets table
    if (!query.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS lockscreen_widgets ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, variant INTEGER, grid_x INTEGER, grid_y INTEGER, grid_w INTEGER, grid_h INTEGER, text TEXT, fontSize INTEGER, fontFamily TEXT, useTheme INTEGER, isBold INTEGER, padding INTEGER DEFAULT 0, transparent INTEGER DEFAULT 1, is24h INTEGER DEFAULT 1, dateSize INTEGER DEFAULT 10, offsetX INTEGER DEFAULT 0, offsetY INTEGER DEFAULT 0, timeOpacity REAL DEFAULT 1.0, dateOpacity REAL DEFAULT 0.7, blendAccent INTEGER DEFAULT 1, blendRatio REAL DEFAULT 0.2"
        ")"
    ))) {
        qWarning() << "[Storage C++] Failed to create lockscreen_widgets table:" << query.lastError().text();
    }

    // Guarded database migrations
    safelyAddColumn(QStringLiteral("widgets"), QStringLiteral("echoChar"), QStringLiteral("TEXT DEFAULT '•'"));
    safelyAddColumn(QStringLiteral("widgets"), QStringLiteral("showFocusBorder"), QStringLiteral("INTEGER DEFAULT 1"));
    safelyAddColumn(QStringLiteral("widgets"), QStringLiteral("dateFontFamily"), QStringLiteral("TEXT DEFAULT 'system-ui:600'"));
    safelyAddColumn(QStringLiteral("widgets"), QStringLiteral("authWidth"), QStringLiteral("INTEGER DEFAULT 0"));
    safelyAddColumn(QStringLiteral("widgets"), QStringLiteral("authHeight"), QStringLiteral("INTEGER DEFAULT 0"));
    safelyAddColumn(QStringLiteral("widgets"), QStringLiteral("showTemp"), QStringLiteral("INTEGER DEFAULT 1"));
    safelyAddColumn(QStringLiteral("widgets"), QStringLiteral("timeColorIndex"), QStringLiteral("INTEGER DEFAULT 8"));
    safelyAddColumn(QStringLiteral("widgets"), QStringLiteral("dateColorIndex"), QStringLiteral("INTEGER DEFAULT 5"));
    safelyAddColumn(QStringLiteral("widgets"), QStringLiteral("dateSpacing"), QStringLiteral("INTEGER DEFAULT 4"));

    safelyAddColumn(QStringLiteral("lockscreen_widgets"), QStringLiteral("echoChar"), QStringLiteral("TEXT DEFAULT '•'"));
    safelyAddColumn(QStringLiteral("lockscreen_widgets"), QStringLiteral("showFocusBorder"), QStringLiteral("INTEGER DEFAULT 1"));
    safelyAddColumn(QStringLiteral("lockscreen_widgets"), QStringLiteral("dateFontFamily"), QStringLiteral("TEXT DEFAULT 'system-ui:600'"));
    safelyAddColumn(QStringLiteral("lockscreen_widgets"), QStringLiteral("authWidth"), QStringLiteral("INTEGER DEFAULT 0"));
    safelyAddColumn(QStringLiteral("lockscreen_widgets"), QStringLiteral("authHeight"), QStringLiteral("INTEGER DEFAULT 0"));
    safelyAddColumn(QStringLiteral("lockscreen_widgets"), QStringLiteral("showTemp"), QStringLiteral("INTEGER DEFAULT 1"));
    safelyAddColumn(QStringLiteral("lockscreen_widgets"), QStringLiteral("timeColorIndex"), QStringLiteral("INTEGER DEFAULT 8"));
    safelyAddColumn(QStringLiteral("lockscreen_widgets"), QStringLiteral("dateColorIndex"), QStringLiteral("INTEGER DEFAULT 5"));
    safelyAddColumn(QStringLiteral("lockscreen_widgets"), QStringLiteral("dateSpacing"), QStringLiteral("INTEGER DEFAULT 4"));
    
    qDebug() << "[Storage C++] Database schema migrations successfully parsed.";
}

void Storage::safelyAddColumn(const QString &table, const QString &column, const QString &typeAndDefault) {
    QSqlQuery query(m_db);
    if (query.exec(QString("PRAGMA table_info(%1)").arg(table))) {
        bool exists = false;
        while (query.next()) {
            if (query.value(1).toString() == column) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            QSqlQuery alterQuery(m_db);
            if (!alterQuery.exec(QString("ALTER TABLE %1 ADD COLUMN %2 %3").arg(table, column, typeAndDefault))) {
                qWarning() << "[Storage C++] Failed to migrate column:" << column << "on table:" << table << alterQuery.lastError().text();
            } else {
                qDebug() << "[Storage C++] Migrated column:" << column << "to table:" << table;
            }
        }
    }
}

void Storage::saveLayout(const QJsonArray &layout) {
    if (!m_db.isOpen() && !m_db.open()) return;
    
    m_db.transaction();
    QSqlQuery query(m_db);
    query.exec(QStringLiteral("DELETE FROM widgets"));
    
    query.prepare(QStringLiteral("INSERT INTO widgets (type, variant, grid_x, grid_y, grid_w, grid_h, text, fontSize, fontFamily, useTheme, isBold, padding, transparent, is24h, dateSize, offsetX, offsetY, timeOpacity, dateOpacity, blendAccent, blendRatio, echoChar, showFocusBorder, dateFontFamily, authWidth, authHeight, showTemp, timeColorIndex, dateColorIndex, dateSpacing) VALUES (:type, :variant, :grid_x, :grid_y, :grid_w, :grid_h, :text, :fontSize, :fontFamily, :useTheme, :isBold, :padding, :transparent, :is24h, :dateSize, :offsetX, :offsetY, :timeOpacity, :dateOpacity, :blendAccent, :blendRatio, :echoChar, :showFocusBorder, :dateFontFamily, :authWidth, :authHeight, :showTemp, :timeColorIndex, :dateColorIndex, :dateSpacing)"));
    
    for (const QJsonValue &value : layout) {
        QJsonObject obj = value.toObject();
        query.bindValue(":type", obj.value("type").toString()); 
        query.bindValue(":variant", obj.value("variant").toInt()); 
        query.bindValue(":grid_x", obj.value("grid_x").toInt()); 
        query.bindValue(":grid_y", obj.value("grid_y").toInt()); 
        query.bindValue(":grid_w", obj.value("grid_w").toInt()); 
        query.bindValue(":grid_h", obj.value("grid_h").toInt()); 
        query.bindValue(":text", obj.value("text").toString()); 
        query.bindValue(":fontSize", obj.value("fontSize").toInt()); 
        query.bindValue(":fontFamily", obj.value("fontFamily").toString()); 
        query.bindValue(":useTheme", obj.value("useTheme").toBool() ? 1 : 0); 
        query.bindValue(":isBold", obj.value("isBold").toBool() ? 1 : 0); 
        query.bindValue(":padding", obj.value("padding").toInt()); 
        query.bindValue(":transparent", obj.value("transparent").toBool() ? 1 : 0); 
        query.bindValue(":is24h", obj.value("is24h").toBool() ? 1 : 0); 
        query.bindValue(":dateSize", obj.value("dateSize").toInt()); 
        query.bindValue(":offsetX", obj.value("offsetX").toInt()); 
        query.bindValue(":offsetY", obj.value("offsetY").toInt()); 
        query.bindValue(":timeOpacity", obj.value("timeOpacity").toDouble(1.0)); 
        query.bindValue(":dateOpacity", obj.value("dateOpacity").toDouble(0.7)); 
        query.bindValue(":blendAccent", obj.value("blendAccent").toBool() ? 1 : 0); 
        query.bindValue(":blendRatio", obj.value("blendRatio").toDouble(0.2)); 
        query.bindValue(":echoChar", obj.value("echoChar").toString(QStringLiteral("•"))); 
        query.bindValue(":showFocusBorder", obj.value("showFocusBorder").toBool(true) ? 1 : 0); 
        query.bindValue(":dateFontFamily", obj.value("dateFontFamily").toString(QStringLiteral("system-ui:600"))); 
        query.bindValue(":authWidth", obj.value("authWidth").toInt(0)); 
        query.bindValue(":authHeight", obj.value("authHeight").toInt(0)); 
        query.bindValue(":showTemp", obj.value("showTemp").toBool(true) ? 1 : 0);
        query.bindValue(":timeColorIndex", obj.value("timeColorIndex").toInt(8));
        query.bindValue(":dateColorIndex", obj.value("dateColorIndex").toInt(5));
        query.bindValue(":dateSpacing", obj.value("dateSpacing").toInt(4));
        query.exec();
    }
    
    m_db.commit();
}

QJsonArray Storage::loadLayout() {
    QJsonArray arr;
    if (!m_db.isOpen() && !m_db.open()) return arr;
    QSqlQuery query(QStringLiteral("SELECT type, variant, grid_x, grid_y, grid_w, grid_h, text, fontSize, fontFamily, useTheme, isBold, padding, transparent, is24h, dateSize, offsetX, offsetY, timeOpacity, dateOpacity, blendAccent, blendRatio, echoChar, showFocusBorder, dateFontFamily, authWidth, authHeight, showTemp, timeColorIndex, dateColorIndex, dateSpacing FROM widgets ORDER BY id ASC"), m_db);
    while (query.next()) {
        QJsonObject obj;
        obj.insert("type", query.value(0).toString()); 
        obj.insert("variant", query.value(1).toInt()); 
        obj.insert("grid_x", query.value(2).toInt()); 
        obj.insert("grid_y", query.value(3).toInt()); 
        obj.insert("grid_w", query.value(4).toInt()); 
        obj.insert("grid_h", query.value(5).toInt()); 
        obj.insert("text", query.value(6).toString()); 
        obj.insert("fontSize", query.value(7).toInt()); 
        obj.insert("fontFamily", query.value(8).toString()); 
        obj.insert("useTheme", query.value(9).toInt() != 0); 
        obj.insert("isBold", query.value(10).toInt() != 0); 
        obj.insert("padding", query.value(11).toInt()); 
        obj.insert("transparent", query.value(12).toInt() != 0); 
        obj.insert("is24h", query.value(13).toInt() != 0); 
        obj.insert("dateSize", query.value(14).toInt()); 
        obj.insert("offsetX", query.value(15).toInt()); 
        obj.insert("offsetY", query.value(16).toInt()); 
        obj.insert("timeOpacity", query.value(17).toDouble()); 
        obj.insert("dateOpacity", query.value(18).toDouble()); 
        obj.insert("blendAccent", query.value(19).toInt() != 0); 
        obj.insert("blendRatio", query.value(20).toDouble()); 
        obj.insert("echoChar", query.value(21).toString()); 
        obj.insert("showFocusBorder", query.value(22).toInt() != 0); 
        obj.insert("dateFontFamily", query.value(23).toString()); 
        obj.insert("authWidth", query.value(24).toInt(0)); 
        obj.insert("authHeight", query.value(25).toInt(0)); 
        obj.insert("showTemp", query.value(26).toInt() != 0);
        obj.insert("timeColorIndex", query.value(27).toInt());
        obj.insert("dateColorIndex", query.value(28).toInt());
        obj.insert("dateSpacing", query.value(29).toInt());
        arr.append(obj);
    }
    return arr;
}

void Storage::saveLockscreenLayout(const QJsonArray &layout) {
    if (!m_db.isOpen() && !m_db.open()) return;
    
    m_db.transaction();
    QSqlQuery query(m_db);
    query.exec(QStringLiteral("DELETE FROM lockscreen_widgets"));
    
    query.prepare(QStringLiteral("INSERT INTO lockscreen_widgets (type, variant, grid_x, grid_y, grid_w, grid_h, text, fontSize, fontFamily, useTheme, isBold, padding, transparent, is24h, dateSize, offsetX, offsetY, timeOpacity, dateOpacity, blendAccent, blendRatio, echoChar, showFocusBorder, dateFontFamily, authWidth, authHeight, showTemp, timeColorIndex, dateColorIndex, dateSpacing) VALUES (:type, :variant, :grid_x, :grid_y, :grid_w, :grid_h, :text, :fontSize, :fontFamily, :useTheme, :isBold, :padding, :transparent, :is24h, :dateSize, :offsetX, :offsetY, :timeOpacity, :dateOpacity, :blendAccent, :blendRatio, :echoChar, :showFocusBorder, :dateFontFamily, :authWidth, :authHeight, :showTemp, :timeColorIndex, :dateColorIndex, :dateSpacing)"));
    
    for (const QJsonValue &value : layout) {
        QJsonObject obj = value.toObject();
        query.bindValue(":type", obj.value("type").toString()); 
        query.bindValue(":variant", obj.value("variant").toInt()); 
        query.bindValue(":grid_x", obj.value("grid_x").toInt()); 
        query.bindValue(":grid_y", obj.value("grid_y").toInt()); 
        query.bindValue(":grid_w", obj.value("grid_w").toInt()); 
        query.bindValue(":grid_h", obj.value("grid_h").toInt()); 
        query.bindValue(":text", obj.value("text").toString()); 
        query.bindValue(":fontSize", obj.value("fontSize").toInt()); 
        query.bindValue(":fontFamily", obj.value("fontFamily").toString()); 
        query.bindValue(":useTheme", obj.value("useTheme").toBool() ? 1 : 0); 
        query.bindValue(":isBold", obj.value("isBold").toBool() ? 1 : 0); 
        query.bindValue(":padding", obj.value("padding").toInt()); 
        query.bindValue(":transparent", obj.value("transparent").toBool() ? 1 : 0); 
        query.bindValue(":is24h", obj.value("is24h").toBool() ? 1 : 0); 
        query.bindValue(":dateSize", obj.value("dateSize").toInt()); 
        query.bindValue(":offsetX", obj.value("offsetX").toInt()); 
        query.bindValue(":offsetY", obj.value("offsetY").toInt()); 
        query.bindValue(":timeOpacity", obj.value("timeOpacity").toDouble(1.0)); 
        query.bindValue(":dateOpacity", obj.value("dateOpacity").toDouble(0.7)); 
        query.bindValue(":blendAccent", obj.value("blendAccent").toBool() ? 1 : 0); 
        query.bindValue(":blendRatio", obj.value("blendRatio").toDouble(0.2)); 
        query.bindValue(":echoChar", obj.value("echoChar").toString(QStringLiteral("•"))); 
        query.bindValue(":showFocusBorder", obj.value("showFocusBorder").toBool(true) ? 1 : 0); 
        query.bindValue(":dateFontFamily", obj.value("dateFontFamily").toString(QStringLiteral("system-ui:600"))); 
        query.bindValue(":authWidth", obj.value("authWidth").toInt(0)); 
        query.bindValue(":authHeight", obj.value("authHeight").toInt(0)); 
        query.bindValue(":showTemp", obj.value("showTemp").toBool(true) ? 1 : 0);
        query.bindValue(":timeColorIndex", obj.value("timeColorIndex").toInt(8));
        query.bindValue(":dateColorIndex", obj.value("dateColorIndex").toInt(5));
        query.bindValue(":dateSpacing", obj.value("dateSpacing").toInt(4));
        query.exec();
    }
    m_db.commit();
}

QJsonArray Storage::loadLockscreenLayout() {
    QJsonArray arr;
    if (!m_db.isOpen() && !m_db.open()) return arr;
    QSqlQuery query(QStringLiteral("SELECT type, variant, grid_x, grid_y, grid_w, grid_h, text, fontSize, fontFamily, useTheme, isBold, padding, transparent, is24h, dateSize, offsetX, offsetY, timeOpacity, dateOpacity, blendAccent, blendRatio, echoChar, showFocusBorder, dateFontFamily, authWidth, authHeight, showTemp, timeColorIndex, dateColorIndex, dateSpacing FROM lockscreen_widgets ORDER BY id ASC"), m_db);
    while (query.next()) {
        QJsonObject obj;
        obj.insert("type", query.value(0).toString()); 
        obj.insert("variant", query.value(1).toInt()); 
        obj.insert("grid_x", query.value(2).toInt()); 
        obj.insert("grid_y", query.value(3).toInt()); 
        obj.insert("grid_w", query.value(4).toInt()); 
        obj.insert("grid_h", query.value(5).toInt()); 
        obj.insert("text", query.value(6).toString()); 
        obj.insert("fontSize", query.value(7).toInt()); 
        obj.insert("fontFamily", query.value(8).toString()); 
        obj.insert("useTheme", query.value(9).toInt() != 0); 
        obj.insert("isBold", query.value(10).toInt() != 0); 
        obj.insert("padding", query.value(11).toInt()); 
        obj.insert("transparent", query.value(12).toInt() != 0); 
        obj.insert("is24h", query.value(13).toInt() != 0); 
        obj.insert("dateSize", query.value(14).toInt()); 
        obj.insert("offsetX", query.value(15).toInt()); 
        obj.insert("offsetY", query.value(16).toInt()); 
        obj.insert("timeOpacity", query.value(17).toDouble()); 
        obj.insert("dateOpacity", query.value(18).toDouble()); 
        obj.insert("blendAccent", query.value(19).toInt() != 0); 
        obj.insert("blendRatio", query.value(20).toDouble()); 
        obj.insert("echoChar", query.value(21).toString()); 
        obj.insert("showFocusBorder", query.value(22).toInt() != 0); 
        obj.insert("dateFontFamily", query.value(23).toString()); 
        obj.insert("authWidth", query.value(24).toInt(0)); 
        obj.insert("authHeight", query.value(25).toInt(0)); 
        obj.insert("showTemp", query.value(26).toInt() != 0);
        obj.insert("timeColorIndex", query.value(27).toInt());
        obj.insert("dateColorIndex", query.value(28).toInt());
        obj.insert("dateSpacing", query.value(29).toInt());
        arr.append(obj);
    }
    return arr;
}