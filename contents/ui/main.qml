import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    Plasmoid.title: i18n("Netspeed Monitor")
    preferredRepresentation: compactRepresentation

    property real prevRx: -1
    property real prevTx: -1
    property real rxSpeed: 0
    property real txSpeed: 0
    property real totalRx: 0
    property real totalTx: 0

    readonly property string rxText: "↓ " + formatSpeed(rxSpeed)
    readonly property string txText: "↑ " + formatSpeed(txSpeed)

    // Pulled from the active Plasma color scheme so they track light/dark themes.
    readonly property color rxColor: Kirigami.Theme.positiveTextColor
    readonly property color txColor: Kirigami.Theme.highlightColor

    toolTipMainText: i18n("Network Speed")
    toolTipSubText: i18n("Download: %1\nUpload: %2\n\nSession total down: %3\nSession total up: %4",
                         formatSpeed(rxSpeed), formatSpeed(txSpeed),
                         formatBytes(totalRx), formatBytes(totalTx))

    function formatSpeed(bytes) {
        if (bytes >= 1048576) {
            return (bytes / 1048576).toFixed(1) + " MB/s";
        } else if (bytes >= 1024) {
            return (bytes / 1024).toFixed(0) + " KB/s";
        }
        return Math.round(bytes) + " B/s";
    }

    function formatBytes(bytes) {
        if (bytes >= 1073741824) {
            return (bytes / 1073741824).toFixed(2) + " GB";
        } else if (bytes >= 1048576) {
            return (bytes / 1048576).toFixed(1) + " MB";
        } else if (bytes >= 1024) {
            return (bytes / 1024).toFixed(0) + " KB";
        }
        return Math.round(bytes) + " B";
    }

    // Skip loopback and virtual bridges/containers so traffic isn't counted twice.
    function isRealInterface(name) {
        return name !== "lo"
            && name.indexOf("docker") !== 0
            && name.indexOf("veth") !== 0
            && name.indexOf("br-") !== 0
            && name.indexOf("virbr") !== 0;
    }

    function parseData(text) {
        var lines = text.split('\n');
        var currentTotalRx = 0;
        var currentTotalTx = 0;

        for (var i = 2; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line) continue;
            var colon = line.indexOf(':');
            if (colon < 0) continue;
            var name = line.substring(0, colon).trim();
            if (!isRealInterface(name)) continue;
            var parts = line.substring(colon + 1).trim().split(/\s+/);
            if (parts.length < 9) continue;
            currentTotalRx += parseInt(parts[0], 10);
            currentTotalTx += parseInt(parts[8], 10);
        }

        if (prevRx >= 0) {
            var rxDiff = Math.max(0, currentTotalRx - prevRx);
            var txDiff = Math.max(0, currentTotalTx - prevTx);
            // Counters are sampled on a 1s timer, so the delta is already bytes/s.
            rxSpeed = rxDiff;
            txSpeed = txDiff;
            totalRx += rxDiff;
            totalTx += txDiff;
        }

        prevRx = currentTotalRx;
        prevTx = currentTotalTx;
    }

    Plasma5Support.DataSource {
        id: netSource
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source);
            if (data["exit code"] === 0) {
                root.parseData(data["stdout"]);
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netSource.connectSource("cat /proc/net/dev")
    }

    compactRepresentation: MouseArea {
        id: compactArea

        readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

        Layout.minimumWidth: isVertical ? 0 : compactLayout.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.maximumWidth: isVertical ? Infinity : Layout.minimumWidth
        Layout.minimumHeight: isVertical ? compactLayout.implicitHeight + Kirigami.Units.smallSpacing * 2 : 0

        onClicked: root.expanded = !root.expanded

        ColumnLayout {
            id: compactLayout
            anchors.centerIn: parent
            spacing: 0

            PlasmaComponents.Label {
                text: root.rxText
                color: root.rxColor
                font.family: Kirigami.Theme.fixedFont.family
                font.pixelSize: Math.max(8, Math.min(Kirigami.Theme.defaultFont.pixelSize,
                                                     Math.floor(compactArea.height / 2) - 2))
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                text: root.txText
                color: root.txColor
                font.family: Kirigami.Theme.fixedFont.family
                font.pixelSize: Math.max(8, Math.min(Kirigami.Theme.defaultFont.pixelSize,
                                                     Math.floor(compactArea.height / 2) - 2))
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }
        }
    }

    fullRepresentation: ColumnLayout {
        id: fullLayout

        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: implicitHeight
        Layout.preferredHeight: implicitHeight
        Layout.maximumHeight: implicitHeight
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            text: i18n("Network Speed")
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        GridLayout {
            columns: 2
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.largeSpacing
            Layout.alignment: Qt.AlignHCenter

            PlasmaComponents.Label { text: i18n("Download:") }
            PlasmaComponents.Label {
                text: "↓ " + root.formatSpeed(root.rxSpeed)
                color: root.rxColor
                font.family: Kirigami.Theme.fixedFont.family
                font.bold: true
            }

            PlasmaComponents.Label { text: i18n("Upload:") }
            PlasmaComponents.Label {
                text: "↑ " + root.formatSpeed(root.txSpeed)
                color: root.txColor
                font.family: Kirigami.Theme.fixedFont.family
                font.bold: true
            }

            PlasmaComponents.Label { text: i18n("Total down:") }
            PlasmaComponents.Label {
                text: root.formatBytes(root.totalRx)
                color: root.rxColor
                font.family: Kirigami.Theme.fixedFont.family
            }

            PlasmaComponents.Label { text: i18n("Total up:") }
            PlasmaComponents.Label {
                text: root.formatBytes(root.totalTx)
                color: root.txColor
                font.family: Kirigami.Theme.fixedFont.family
            }
        }

        Item { Layout.fillHeight: true }
    }
}
