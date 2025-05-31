
import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: root


    implicitWidth: Kirigami.Units.gridUnit * 5


    // --- Properties ---
    property var prayerTimesData: ({})
    property PlasmoidItem plasmoidItem
    property int languageIndex: 0
    property bool hourFormat: false

    readonly property int maxCompactLabelPixelSize: Kirigami.Theme.defaultFont.pixelSize
    readonly property int minCompactLabelPixelSize: 8

    // --- Signal Handlers to Update Text ---
    onLanguageIndexChanged: {
        nextPrayerLabel.text = getNextPrayerInfo();
    }
    onHourFormatChanged: {
        nextPrayerLabel.text = getNextPrayerInfo();
    }
    onPrayerTimesDataChanged: {
        nextPrayerLabel.text = getNextPrayerInfo();
    }

    // --- MouseArea ---
    MouseArea {
        id: mouseArea
        property bool wasExpanded: false
        anchors.fill: parent
        hoverEnabled: true
        onPressed: wasExpanded = root.plasmoidItem ? root.plasmoidItem.expanded : false
        onClicked: mouse => {
            if (root.plasmoidItem) {
                root.plasmoidItem.expanded = !wasExpanded
            }
        }
    }

    // --- Label ---
    PlasmaComponents.Label {
        id: nextPrayerLabel
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap

        font.pixelSize: {
            let calculatedSize = Math.floor(root.height / 2.5);
            return Math.max(root.minCompactLabelPixelSize, Math.min(calculatedSize, root.maxCompactLabelPixelSize));
        }
    }

    // --- Logic Functions ---
    function getPrayerName(langIndex, prayerKey) {
        if (langIndex === 0) {
            return prayerKey;
        } else {
            const arabicPrayers = {
                "Fajr": "الفجر", "Sunrise": "الشروق", "Dhuhr": "الظهر",
                "Asr": "العصر", "Maghrib": "المغرب", "Isha": "العشاء"
            };
            return arabicPrayers[prayerKey] || prayerKey;
        }
    }

    function to12HourTime(timeString24, use12HourFormat) {
        if (!timeString24) return "\u202A00:00\u202C";

        const LRE = "\u202A";
        const PDF = "\u202C";
        const NBSP = "\u00A0";

        if (use12HourFormat) {
            let parts = timeString24.split(':');
            let hours = parseInt(parts[0], 10);
            let minutes = parseInt(parts[1], 10);
            let period = hours >= 12 ? i18n("PM") : i18n("AM");
            hours = hours % 12 || 12;
            let timePart = `${hours}:${String(minutes).padStart(2, '0')}`;
            return `${LRE}${timePart}${NBSP}${period}${PDF}`;
        } else {
            return `${LRE}${timeString24}${PDF}`;
        }
    }

    function getNextPrayerInfo() {
        const prayerData = root.prayerTimesData;
        if (!prayerData || Object.keys(prayerData).length === 0 || !prayerData.Fajr) {
            return i18n("Loading...");
        }

        const prayerKeys = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
        const now = new Date();
        const currentTimeStr = ("0" + now.getHours()).slice(-2) + ":" + ("0" + now.getMinutes()).slice(-2);

        let nextPrayerKey = "";
        let nextPrayerRawTime = "";

        for (const key of prayerKeys) {
            if (prayerData[key] && prayerData[key] > currentTimeStr) {
                nextPrayerKey = key;
                nextPrayerRawTime = prayerData[key];
                break;
            }
        }

        if (nextPrayerKey === "" && prayerData["Fajr"]) {
            nextPrayerKey = "Fajr";
            nextPrayerRawTime = prayerData["Fajr"];
        } else if (nextPrayerKey === "") {
            return i18n("N/A");
        }

        let translatedName = getPrayerName(root.languageIndex, nextPrayerKey);
        let formattedTime = to12HourTime(nextPrayerRawTime, root.hourFormat);

        return translatedName + "\n" + formattedTime;
    }

    // --- Timer & Initial Setup ---
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            nextPrayerLabel.text = getNextPrayerInfo();
        }
    }

    Component.onCompleted: {
        nextPrayerLabel.text = getNextPrayerInfo();
    }
}
