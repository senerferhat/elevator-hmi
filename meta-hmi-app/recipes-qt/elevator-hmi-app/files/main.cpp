#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QStringList>
#include <QUrl>
#include <cstdio>

// Layouts match design/elevator-hmi at 800×1280:
//   car    full portrait elevator GUI
//   video  same GUI compacted under an empty video pane (SD playback later)
static const char kUsage[] =
    "Usage: elevator-hmi [car|video]\n"
    "  car    full portrait HMI (default)\n"
    "  video  portrait HMI with empty video pane\n"
    "\n"
    "On the board, `hmi car` / `hmi video` restarts the service with the\n"
    "chosen layout and remembers it across reboot in /etc/elevator-hmi.layout.\n";

static bool isLayout(const QString &s)
{
    return s == QLatin1String("car") || s == QLatin1String("video");
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QString layout = QStringLiteral("car");
    const QStringList args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        const QString a = args.at(i);
        if (a == QLatin1String("-h") || a == QLatin1String("--help")) {
            std::fputs(kUsage, stdout);
            return 0;
        }
        if (a.startsWith(QLatin1String("--layout="))) {
            layout = a.mid(9);
        } else if (isLayout(a)) {
            layout = a;
        } else {
            std::fprintf(stderr, "unknown argument: %s\n%s", qPrintable(a), kUsage);
            return 2;
        }
    }
    if (!isLayout(layout)) {
        std::fprintf(stderr, "unknown layout: %s\n%s", qPrintable(layout), kUsage);
        return 2;
    }

    QQmlApplicationEngine engine;
    engine.load(QUrl::fromLocalFile(QStringLiteral("/usr/share/elevator-hmi/main.qml")));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }

    return app.exec();
}

