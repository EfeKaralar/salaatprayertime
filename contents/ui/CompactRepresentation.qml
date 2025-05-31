
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
    property bool prePrayerWarningActive: false

    property color defaultBackgroundColor: "transparent"
    property color warningBackgroundColor: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                                   Kirigami.Theme.highlightColor.g,
                                                   Kirigami.Theme.highlightColor.b,
                                                   0.25)

    readonly property int maxCompactLabelPixelSize: Kirigami.Theme.defaultFont.pixelSize
    readonly property int minCompactLabelPixelSize: 8

    // --- Explicitly control animation and color reset ---
    onPrePrayerWarningActiveChanged: {
        if (prePrayerWarningActive) {
            alertBackground.color = warningBackgroundColor;
            flashAnimation.start();
        } else {
            flashAnimation.stop();
            alertBackground.color = defaultBackgroundColor;
        }
    }

    // --- Background Rectangle for Animation ---
    Rectangle {
        id: alertBackground
        anchors.fill: parent
        color: root.defaultBackgroundColor
        radius: Kirigami.Theme.smallRadius

        SequentialAnimation {
            id: flashAnimation
            // target: alertBackground // Not needed here, target is on ColorAnimation
            // property: "color"    // <<<< THIS LINE WAS THE ERROR AND IS REMOVED
            loops: Animation.Infinite
            running: false

            ColorAnimation { target: alertBackground; property: "color"; to: root.defaultBackgroundColor; duration: 750 }
            ColorAnimation { target: alertBackground; property: "color"; to: root.warningBackgroundColor; duration: 750 }
        }
    }

    // --- Signal Handlers to Update Display ---
    onLanguageIndexChanged: updateDisplay()
    onHourFormatChanged: updateDisplay()
    onPrayerTimesDataChanged: updateDisplay()

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
        // Text will be set by updateDisplay()
    }

    // --- Logic Functions ---
    function getPrayerName(langIndex, prayerKey) {
        if (langIndex === 0) { return prayerKey; }
        else {
            const arabicPrayers = { "Fajr": "الفجر", "Sunrise": "الشروق", "Dhuhr": "الظهر", "Asr": "العصر", "Maghrib": "المغرب", "Isha": "العشاء"};
            return arabicPrayers[prayerKey] || prayerKey;
        }
    }

    function to12HourTime(timeString24, use12HourFormat) {
        if (!timeString24 || timeString24 === "--:--") return "\u202A--:--\u202C";
        const LRE = "\u202A"; const PDF = "\u202C"; const NBSP = "\u00A0";
        if (use12HourFormat) {
            let parts = timeString24.split(':');
            let hours = parseInt(parts[0], 10);
            let minutes = parseInt(parts[1], 10);
            if(isNaN(hours) || isNaN(minutes)) return "\u202A--:--\u202C";
            let period = hours >= 12 ? i18n("PM") : i18n("AM");
            hours = hours % 12 || 12;
            let timePart = `${hours}:${String(minutes).padStart(2, '0')}`;
            return `${LRE}${timePart}${NBSP}${period}${PDF}`;
        } else {
            return `${LRE}${timeString24}${PDF}`;
        }
    }

    function parseTime(timeString) {
        if (!timeString || timeString === "--:--") return null;
        let parts = timeString.split(':');
        if (parts.length !== 2) return null;
        let hours = parseInt(parts[0], 10);
        let minutes = parseInt(parts[1], 10);
        if (isNaN(hours) || isNaN(minutes)) return null;

        let dateObj = new Date();
        dateObj.setHours(hours);
        dateObj.setMinutes(minutes);
        dateObj.setSeconds(0);
        dateObj.setMilliseconds(0);
        return dateObj;
    }

    function getNextPrayerData() {
        const prayerData = root.prayerTimesData;
        if (!prayerData || Object.keys(prayerData).length === 0 || !prayerData.Fajr || prayerData.Fajr === "--:--") {
            return { nameText: i18n("Loading..."), timeText: "", nextPrayerDate: null };
        }

        const prayerKeys = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
        const now = new Date();
        const currentTimeStr = ("0" + now.getHours()).slice(-2) + ":" + ("0" + now.getMinutes()).slice(-2);

        let nextPrayerKey = "";
        let nextPrayerRawTime = "";
        let nextPrayerDateObj = null;

        for (const key of prayerKeys) {
            if (prayerData[key] && prayerData[key] !== "--:--" && prayerData[key] > currentTimeStr) {
                nextPrayerKey = key;
                nextPrayerRawTime = prayerData[key];
                break;
            }
        }

        if (nextPrayerKey === "" && prayerData["Fajr"] && prayerData["Fajr"] !== "--:--") {
            nextPrayerKey = "Fajr";
            nextPrayerRawTime = prayerData["Fajr"];
            let fajrTimeToday = parseTime(nextPrayerRawTime);
            if (fajrTimeToday) {
                nextPrayerDateObj = new Date(fajrTimeToday.getTime());
                if (now > fajrTimeToday) {
                    nextPrayerDateObj.setDate(nextPrayerDateObj.getDate() + 1);
                }
            }
        } else if (nextPrayerRawTime) {
            nextPrayerDateObj = parseTime(nextPrayerRawTime);
        }

        if (!nextPrayerKey || !nextPrayerDateObj) {
            return { nameText: i18n("N/A"), timeText: "", nextPrayerDate: null };
        }

        let translatedName = getPrayerName(root.languageIndex, nextPrayerKey);
        let formattedTime = to12HourTime(nextPrayerRawTime, root.hourFormat);

        return {
            nameText: translatedName,
            timeText: formattedTime,
            nextPrayerDate: nextPrayerDateObj
        };
    }

    function updateDisplay() {
        let data = getNextPrayerData();
        nextPrayerLabel.text = data.nameText + "\n" + data.timeText;

        if (data.nextPrayerDate) {
            const nowMs = new Date().getTime();
            const prayerMs = data.nextPrayerDate.getTime();
            const diffMs = prayerMs - nowMs;
            const fiveMinutesInMs = 5 * 60 * 1000;

            root.prePrayerWarningActive = (diffMs > 0 && diffMs <= fiveMinutesInMs);
        } else {
            root.prePrayerWarningActive = false;
        }
    }

    // --- Timer & Initial Setup ---
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: updateDisplay()
    }

    Component.onCompleted: {
        updateDisplay();
    }
}
