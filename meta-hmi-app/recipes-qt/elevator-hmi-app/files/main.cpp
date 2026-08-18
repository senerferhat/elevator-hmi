#include <QGuiApplication>
#include <QList>
#include <QQmlApplicationEngine>
#include <QQmlError>
#include <QStringList>
#include <QUrl>
#include <cstdio>

// Four layouts from design/elevator-hmi, all installed:
//   portrait           800×1280 full HMI
//   portrait-video     800×1280 HMI + empty video pane
//   landscape          1280×800 full HMI, rotated onto the portrait panel
//   landscape-video    1280×800 split, rotated onto the portrait panel
// Aliases: car/vertical → portrait; video/vertical-video → portrait-video
static const char kUsage[] =
    "Usage: elevator-hmi [LAYOUT] [--rot=90|270]\n"
    "  portrait           full portrait HMI 800×1280 (default)\n"
    "  portrait-video     portrait HMI + empty video pane\n"
    "  landscape          full landscape HMI 1280×800 (rotated)\n"
    "  landscape-video    landscape HMI + empty video pane (rotated)\n"
    "  --rot=90|270       landscape rotation onto the native 800×1280 panel\n"
    "\n"
    "Aliases: car, vertical = portrait; video, vertical-video = portrait-video\n"
    "On the board, `hmi` restarts the service and remembers the choice in\n"
    "/etc/elevator-hmi.layout (and /etc/elevator-hmi.rotation).\n";

static QString canonicalLayout(const QString &s)
{
    if (s == QLatin1String("car") || s == QLatin1String("vertical")
        || s == QLatin1String("portrait"))
        return QStringLiteral("portrait");
    if (s == QLatin1String("video") || s == QLatin1String("vertical-video")
        || s == QLatin1String("portrait-video"))
        return QStringLiteral("portrait-video");
    if (s == QLatin1String("landscape") || s == QLatin1String("landscape-car"))
        return QStringLiteral("landscape");
    if (s == QLatin1String("landscape-video"))
        return QStringLiteral("landscape-video");
    return QString();
}

static bool isRotation(int n)
{
    return n == 90 || n == 270;
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QString layout = QStringLiteral("portrait");
    int rot = 90;
    const QStringList args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        const QString a = args.at(i);
        if (a == QLatin1String("-h") || a == QLatin1String("--help")) {
            std::fputs(kUsage, stdout);
            return 0;
        }
        if (a.startsWith(QLatin1String("--layout="))) {
            const QString c = canonicalLayout(a.mid(9));
            if (c.isEmpty()) {
                std::fprintf(stderr, "unknown layout: %s\n%s", qPrintable(a.mid(9)), kUsage);
                return 2;
            }
            layout = c;
            continue;
        }
        if (a.startsWith(QLatin1String("--rot="))) {
            bool ok = false;
            const int n = a.mid(6).toInt(&ok);
            if (!ok || !isRotation(n)) {
                std::fprintf(stderr, "unknown rotation: %s (use 90 or 270)\n%s",
                             qPrintable(a.mid(6)), kUsage);
                return 2;
            }
            rot = n;
            continue;
        }
        const QString c = canonicalLayout(a);
        if (!c.isEmpty()) {
            layout = c;
            continue;
        }
        std::fprintf(stderr, "unknown argument: %s\n%s", qPrintable(a), kUsage);
        return 2;
    }
    Q_UNUSED(layout);
    Q_UNUSED(rot);
    // QML re-parses argv for layout and --rot. C++ only validates so a bad
    // argument fails before the engine starts.

    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral("/usr/share/elevator-hmi"));
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     [](const QList<QQmlError> &warnings) {
                         for (const QQmlError &e : warnings)
                             std::fprintf(stderr, "QML: %s\n", qPrintable(e.toString()));
                     });
    engine.load(QUrl::fromLocalFile(QStringLiteral("/usr/share/elevator-hmi/main.qml")));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }

    return app.exec();
}
