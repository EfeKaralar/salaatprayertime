// main.qml (Cleaned and Optimized)
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0
import org.kde.notification 1.0
import QtQuick.LocalStorage 2.15 as LocalStorage

PlasmoidItem {
    id: root

    // Layout hints for the panel
    Layout.minimumWidth: Kirigami.Units.gridUnit * 5
    Layout.preferredWidth: Kirigami.Units.gridUnit * 5

    // --- Data Properties ---
    property var times: ({})                 // Raw prayer times from API/Cache
    property var displayPrayerTimes: ({})    // Offset-adjusted times for UI
    property string hijriDateDisplay: "..."   // Formatted Hijri date string for UI
    property var rawHijriDataFromApi: null   // Raw Hijri object from API, used for offset calculation & caching

    // Processed Hijri components for special date logic
    property int currentHijriDay: 0
    property int currentHijriMonth: 0        // Numeric month (1-12)
    property int currentHijriYear: 0
    property string specialIslamicDateMessage: ""

    // Active prayer tracking
    property string lastActivePrayer: ""
    property string activePrayer: ""

    // Configuration dependent properties
    property bool isSmall: width < (Kirigami.Units.gridUnit * 10) || height < (Kirigami.Units.gridUnit * 10)
    property int languageIndex: Plasmoid.configuration.languageIndex || 0 // Default to 0 if undefined

    // --- Timers and Components ---
    Component { id: notificationComponent; Notification { componentName: "plasma_workspace"; eventId: "notification"; autoDelete: true } }

    Timer { // Startup delay timer for initial fetch
        id: startupTimer
        interval: 500 // 0.5 second delay
        repeat: false
        onTriggered: root.fetchTimes()
    }

    Timer { // Main refresh timer (e.g., for daily data integrity check, active prayer update)
        interval: 30000 // 30 seconds
        running: true
        repeat: true
        onTriggered: {
            if (root.displayPrayerTimes.apiGregorianDate && getFormattedDate(new Date()) === root.displayPrayerTimes.apiGregorianDate) {
                if (Object.keys(root.displayPrayerTimes).length > 0 && root.displayPrayerTimes.Fajr !== "--:--") {
                    root.highlightActivePrayer(root.displayPrayerTimes);
                } else if (Object.keys(root.times).length > 0 && root.times.Fajr) { // Raw times available but display not processed
                    processRawTimesAndApplyOffsets();
                }
            } else { // Date has changed or no valid data, fetch new times
                root.fetchTimes();
            }
        }
    }

    // --- Helper Functions ---
    function getDatabase() {
        return LocalStorage.LocalStorage.openDatabaseSync("PrayerTimesCacheDB", "1.0", "Prayer Times Offline Cache", 200000);
    }

    function initDatabase() {
        var db = getDatabase();
        db.transaction(function(tx) {
            tx.executeSql('CREATE TABLE IF NOT EXISTS PrayerDataCache(gregorianDate TEXT PRIMARY KEY, timingsJSON TEXT, hijriJSON TEXT)');
            // console.log("Prayer Times Widget: Database table ensured."); // Optional: keep for first-run debug
        });
    }

    function to12HourTime(timeString, use12HourFormat) {
        if (!timeString || timeString === "--:--") return timeString;
        if (use12HourFormat) {
            let parts = timeString.split(':');
            let hours = parseInt(parts[0], 10);
            let minutes = parseInt(parts[1], 10);
            if (isNaN(hours) || isNaN(minutes)) return timeString; // Should not happen if timeString is valid HH:MM

            let period = hours >= 12 ? i18n("PM") : i18n("AM");
            hours = hours % 12 || 12;
            return `${hours}:${String(minutes).padStart(2, '0')} ${period}`;
        }
        return timeString;
    }

    function parseTime(timeString) {
        if (!timeString || timeString === "--:--") return new Date(0); // Return epoch if invalid
        let parts = timeString.split(':');
        let dateObj = new Date();
        dateObj.setHours(parseInt(parts[0], 10));
        dateObj.setMinutes(parseInt(parts[1], 10));
        dateObj.setSeconds(0);
        dateObj.setMilliseconds(0);
        return dateObj;
    }

    function getPrayerName(langIndex, prayerKey) {
        if (langIndex === 0) { return prayerKey; }
        const arabicPrayers = { "Fajr": "الفجر", "Sunrise": "الشروق", "Dhuhr": "الظهر", "Asr": "العصر", "Maghrib": "المغرب", "Isha": "العشاء" };
        return arabicPrayers[prayerKey] || prayerKey; // Fallback to key if translation missing
    }

    function highlightActivePrayer(currentTimings) {
        if (!currentTimings || !currentTimings.Fajr || currentTimings.Fajr === "--:--") {
            root.activePrayer = ""; // No valid times to determine active prayer
            return;
        }
        var newActivePrayer = "";
        let now = new Date();
        const prayerCheckOrder = ["Isha", "Maghrib", "Asr", "Dhuhr", "Sunrise", "Fajr"];
        let foundActive = false;

        for (const prayer of prayerCheckOrder) {
            if (currentTimings[prayer] && currentTimings[prayer] !== "--:--" && now >= parseTime(currentTimings[prayer])) {
                newActivePrayer = prayer;
                foundActive = true;
                break;
            }
        }

        if (!foundActive) { // If current time is before today's Fajr
            newActivePrayer = "Isha"; // Consider previous day's Isha as active
        }

        if (root.activePrayer !== newActivePrayer) {
            root.lastActivePrayer = root.activePrayer;
            root.activePrayer = newActivePrayer;
            if (root.lastActivePrayer !== "" && root.activePrayer !== "" && Plasmoid.configuration.notifications) {
                var notification = notificationComponent.createObject(root);
                notification.title = i18n("It's %1 time", getPrayerName(root.languageIndex, root.activePrayer));
                notification.sendEvent();
            }
        }
    }

    function getYYYYMMDD(dateObj) {
        let year = dateObj.getFullYear();
        let month = String(dateObj.getMonth() + 1).padStart(2, '0');
        let day = String(dateObj.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    function getFormattedDate(givenDate) { // Returns DD-MM-YYYY
        const day = String(givenDate.getDate()).padStart(2, "0");
        const month = String(givenDate.getMonth() + 1).padStart(2, "0");
        const year = givenDate.getFullYear();
        return `${day}-${month}-${year}`;
    }

    function applyOffsetToTime(timeStrHHMM, offsetMins) {
        if (!timeStrHHMM || timeStrHHMM === "--:--" || typeof offsetMins !== 'number' || offsetMins === 0) {
            return timeStrHHMM;
        }
        let parts = timeStrHHMM.split(':');
        let hours = parseInt(parts[0], 10);
        let minutes = parseInt(parts[1], 10);
        if (isNaN(hours) || isNaN(minutes)) return timeStrHHMM;

        let totalMinutes = (hours * 60) + minutes + offsetMins;
        totalMinutes = ((totalMinutes % 1440) + 1440) % 1440; // Keeps time within 0-1439 minutes

        let finalHours = Math.floor(totalMinutes / 60);
        let finalMinutes = totalMinutes % 60;
        return String(finalHours).padStart(2, '0') + ":" + String(finalMinutes).padStart(2, '0');
    }

    function processRawTimesAndApplyOffsets() {
        const defaultTimesStructure = { Fajr: "--:--", Sunrise: "--:--", Dhuhr: "--:--", Asr: "--:--", Maghrib: "--:--", Isha: "--:--", apiGregorianDate: getFormattedDate(new Date()) };
        if (!root.times || Object.keys(root.times).length === 0 || !root.times.Fajr) {
            root.displayPrayerTimes = { defaultTimesStructure, apiGregorianDate: (root.times && root.times.apiGregorianDate) || defaultTimesStructure.apiGregorianDate };
            root.highlightActivePrayer(root.displayPrayerTimes);
            return;
        }

        let newDisplayTimes = {};
        const prayerKeys = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];
        for (const key of prayerKeys) {
            let offset = Plasmoid.configuration[key.toLowerCase() + "OffsetMinutes"] || 0;
            newDisplayTimes[key] = root.times[key] ? applyOffsetToTime(root.times[key], offset) : "--:--";
        }
        if (root.times.apiGregorianDate) {
            newDisplayTimes.apiGregorianDate = root.times.apiGregorianDate;
        } else { // Should always have an apiGregorianDate if root.times is populated
            newDisplayTimes.apiGregorianDate = getFormattedDate(new Date());
        }
        root.displayPrayerTimes = newDisplayTimes;
        root.highlightActivePrayer(root.displayPrayerTimes);
    }

    function _setProcessedHijriData(hijriDataObject) {
        if (!hijriDataObject || !hijriDataObject.month) {
            root.hijriDateDisplay = i18n("Date unavailable");
            root.currentHijriDay = 0; root.currentHijriMonth = 0; root.currentHijriYear = 0;
        } else {
            root.currentHijriDay = parseInt(hijriDataObject.day, 10);
            root.currentHijriMonth = parseInt(hijriDataObject.month.number, 10);
            root.currentHijriYear = parseInt(hijriDataObject.year, 10);
            let monthNameToDisplay = (root.languageIndex === 1) ? hijriDataObject.month.ar : hijriDataObject.month.en;
            root.hijriDateDisplay = `${root.currentHijriDay} ${monthNameToDisplay} ${root.currentHijriYear}`;
        }
        updateSpecialIslamicDateMessage();
    }

    function updateSpecialIslamicDateMessage() {
        let day = root.currentHijriDay;
        let month = root.currentHijriMonth;
        let message = "";
        if (month === 0 || day === 0) { root.specialIslamicDateMessage = ""; return; }

        if (month === 9) { message = (root.languageIndex === 1) ? "شهر رمضان" : "Month of Ramadan"; }
        else if (month === 10 && day === 1) { message = (root.languageIndex === 1) ? "عيد الفطر" : "Eid al-Fitr"; }
        else if (month === 12) {
            if (day >= 1 && day <= 10) { message = (root.languageIndex === 1) ? "العشر الأوائل من ذي الحجة" : "First 10 Days of Dhu al-Hijjah";
                if (day === 9) { message = (root.languageIndex === 1) ? "يوم عرفة" : "Day of Arafah"; }
                if (day === 10) { message = (root.languageIndex === 1) ? "عيد الأضحى" : "Eid al-Adha"; }
            } else if (day >= 11 && day <= 13) { message = (root.languageIndex === 1) ? "أيام التشريق" : "Days of Tashreeq"; }
        }
        else if (month === 1 && day === 1) { message = (root.languageIndex === 1) ? "رأس السنة الهجرية" : "Islamic New Year"; }
        else if (month === 1 && day === 10) { message = (root.languageIndex === 1) ? "يوم عاشوراء" : "Day of Ashura"; }

        if (message === "") { // Check for Ayyam al-Bid if no other specific message
            if (day === 13 || day === 14 || day === 15) {
                message = (root.languageIndex === 1) ? "الأيام البيض" : "Ayyām al-Bīḍ (The White Days)";
            }
        }
        root.specialIslamicDateMessage = message;
    }

    function fetchTimes() {
        let todayForAPI = getFormattedDate(new Date()); // DD-MM-YYYY
        let URL = `https://api.aladhan.com/v1/timingsByCity/${todayForAPI}?city=${encodeURIComponent(Plasmoid.configuration.city || "Makkah")}&country=${encodeURIComponent(Plasmoid.configuration.country || "Saudi Arabia")}&method=${Plasmoid.configuration.method || 4}&school=${Plasmoid.configuration.school || 0}`;
        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    let responseData = JSON.parse(xhr.responseText).data;
                    root.times = responseData.timings;
                    root.times.apiGregorianDate = responseData.date.gregorian.date; // DD-MM-YYYY
                    root.rawHijriDataFromApi = responseData.date.hijri;

                    processRawTimesAndApplyOffsets();

                    let offset = Plasmoid.configuration.hijriOffset || 0;
                    if (offset !== 0) {
                        let parts = responseData.date.gregorian.date.split('-'); // DD-MM-YYYY
                        let originalJsDate = new Date(parseInt(parts[2]), parseInt(parts[1]) - 1, parseInt(parts[0]));
                        originalJsDate.setDate(originalJsDate.getDate() + offset);

                        let adjustedGregorianDateStr = getFormattedDate(originalJsDate); // DD-MM-YYYY
                        let hijriApiURL = `https://api.aladhan.com/v1/gToH?date=${adjustedGregorianDateStr}`;
                        let hijriXhrNested = new XMLHttpRequest();
                        hijriXhrNested.onreadystatechange = function() {
                            if (hijriXhrNested.readyState === 4) {
                                if (hijriXhrNested.status === 200) {
                                    _setProcessedHijriData(JSON.parse(hijriXhrNested.responseText).data.hijri);
                                } else {
                                    _setProcessedHijriData(root.rawHijriDataFromApi); // Fallback
                                }
                            }
                        };
                        hijriXhrNested.open("GET", hijriApiURL, true);
                        hijriXhrNested.send();
                    } else {
                        _setProcessedHijriData(root.rawHijriDataFromApi);
                    }
                    updateMonthlyCache(); // Update full month cache
                } else {
                    loadFromLocalStorage();
                }
            }
        };
        xhr.open("GET", URL, true);
        xhr.send();
    }

    function saveTodayToLocalStorage() { // Saves raw times and raw hijri
        if (!root.times || !root.times.Fajr || !root.rawHijriDataFromApi || !root.rawHijriDataFromApi.month) {
            return;
        }
        let todayKey = getYYYYMMDD(new Date());
        let cleanTimings = {};
        const prayerKeysToSave = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];
        prayerKeysToSave.forEach(function(pKey) {
            if (root.times[pKey]) cleanTimings[pKey] = root.times[pKey];
        });

            if (Object.keys(cleanTimings).length === 0) return;

            let timingsJson = JSON.stringify(cleanTimings);
        let hijriJson = JSON.stringify(root.rawHijriDataFromApi);
        var db = getDatabase();
        db.transaction(function(tx) {
            try {
                tx.executeSql('REPLACE INTO PrayerDataCache VALUES(?, ?, ?)', [todayKey, timingsJson, hijriJson]);
            } catch (err) { /* Silently fail for now, or log minimally */ }
        });
    }

    function updateMonthlyCache() {
        let now = new Date();
        let year = now.getFullYear();
        let month = now.getMonth() + 1;
        if (!Plasmoid.configuration.city || !Plasmoid.configuration.country) return;

        let URL = `https://api.aladhan.com/v1/calendarByCity/${year}/${month}?city=${encodeURIComponent(Plasmoid.configuration.city)}&country=${encodeURIComponent(Plasmoid.configuration.country)}&method=${Plasmoid.configuration.method}&school=${Plasmoid.configuration.school}`;
        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    let monthlyData = JSON.parse(xhr.responseText).data;
                    if (monthlyData && monthlyData.length > 0) {
                        var db = getDatabase();
                        db.transaction(function(tx) {
                            for (var i = 0; i < monthlyData.length; i++) {
                                let dayData = monthlyData[i];
                                if (!dayData.date || !dayData.date.gregorian || !dayData.date.hijri || !dayData.timings) continue;
                                let gregorianApiDate = dayData.date.gregorian.date;
                                let parts = gregorianApiDate.split('-');
                                if (parts.length !== 3) continue;
                                let dateKey = `${parts[2]}-${parts[1]}-${parts[0]}`; // YYYY-MM-DD

                                let cleanTimings = {};
                                const prayerKeysToSave = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];
                                prayerKeysToSave.forEach(function(pKey){
                                    if(dayData.timings[pKey]) cleanTimings[pKey] = dayData.timings[pKey];
                                });
                                    if (Object.keys(cleanTimings).length > 0) {
                                        try {
                                            tx.executeSql('REPLACE INTO PrayerDataCache VALUES(?, ?, ?)',
                                                          [dateKey, JSON.stringify(cleanTimings), JSON.stringify(dayData.date.hijri)]);
                                        } catch(e) { /* Silently fail for now */ }
                                    }
                            }
                        });
                    }
                }
            }
        };
        xhr.open("GET", URL, true);
        xhr.send();
    }

    function loadFromLocalStorage() {
        let todayKey = getYYYYMMDD(new Date());
        var db = getDatabase();
        var loaded = false;
        db.readTransaction(function(tx) {
            try {
                var rs = tx.executeSql('SELECT timingsJSON, hijriJSON FROM PrayerDataCache WHERE gregorianDate = ?', [todayKey]);
                if (rs.rows.length > 0) {
                    let row = rs.rows.item(0);
                    root.times = JSON.parse(row.timingsJSON);
                    root.times.apiGregorianDate = getFormattedDate(new Date());
                    let hijriDataFromCache = JSON.parse(row.hijriJSON);
                    processRawTimesAndApplyOffsets();
                    _setProcessedHijriData(hijriDataFromCache); // Will call updateSpecialIslamicDateMessage
                    loaded = true;
                }
            } catch (err) { /* Silently fail for now */ }
        });
        if (!loaded) {
            root.times = {};
            processRawTimesAndApplyOffsets();
            root.hijriDateDisplay = i18n("Offline - No data");
            root.specialIslamicDateMessage = "";
        }
    }

    Component.onCompleted: {
        initDatabase();
        startupTimer.start(); // Use startup timer
        Plasmoid.configuration.valueChanged.connect(function(key) {
            if (key.endsWith("OffsetMinutes") && (Object.keys(root.times).length > 0 )) {
                processRawTimesAndApplyOffsets();
            } else if (key === "languageIndex" || key === "city" || key === "country" ||
                key === "method" || key === "school" || key === "hijriOffset") {
                fetchTimes();
                }
        });
    }

    // --- REPRESENTATIONS ---
    preferredRepresentation: isSmall ? compactRepresentation : fullRepresentation
    compactRepresentation: CompactRepresentation {
        prayerTimesData: root.displayPrayerTimes
        plasmoidItem: root
        languageIndex: root.languageIndex
        hourFormat: Plasmoid.configuration.hourFormat
    }

    fullRepresentation: Kirigami.Page {
        id: fullView
        background: Rectangle { color: "transparent" }
        onVisibleChanged: {
            if (visible && Object.keys(root.displayPrayerTimes).length > 0) {
                root.highlightActivePrayer(root.displayPrayerTimes);
            }
        }
        implicitWidth: Kirigami.Units.gridUnit * 22
        Column {
            width: parent.width; padding: Kirigami.Units.largeSpacing; spacing: Kirigami.Units.smallSpacing; anchors.centerIn: parent
            Label { id: arabicPhraseLabel; text: "{صّلِ عَلۓِ مُحَمد ﷺ}"; font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1; font.weight: Font.Bold; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; anchors.horizontalCenter: parent.horizontalCenter; }
            Label { id: hijriDateLabel; text: root.hijriDateDisplay; font.pointSize: Kirigami.Theme.defaultFont.pointSize; font.weight: Font.Bold; opacity: 0.9; anchors.horizontalCenter: parent.horizontalCenter }

            Label { // Special Date Message Label
                id: specialDateMessageLabel
                text: root.specialIslamicDateMessage
                visible: root.specialIslamicDateMessage !== ""
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.italic: true
                opacity: 0.85
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            PlasmaComponents.MenuSeparator { width: parent.width; topPadding: Kirigami.Units.moderateSpacing; bottomPadding: Kirigami.Units.moderateSpacing }

            // Prayer Rows (using root.displayPrayerTimes)
            Rectangle { width: parent.width; height: Kirigami.Units.gridUnit * 2.0; radius: 8; color: root.activePrayer === 'Fajr' ? Kirigami.Theme.highlightColor : "transparent"; RowLayout { anchors.fill: parent; anchors.leftMargin: Kirigami.Units.largeSpacing; anchors.rightMargin: Kirigami.Units.largeSpacing; Label { text: getPrayerName(root.languageIndex, "Fajr"); color: parent.parent.color === Kirigami.Theme.highlightColor ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.weight: Font.Bold; font.pointSize: Kirigami.Theme.defaultFont.pointSize } Item { Layout.fillWidth: true } Label { text: root.to12HourTime(root.displayPrayerTimes.Fajr, Plasmoid.configuration.hourFormat); color: parent.parent.color === Kirigami.Theme.highlightColor ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.pointSize: Kirigami.Theme.defaultFont.pointSize } } }
            Rectangle { width: parent.width; height: Kirigami.Units.gridUnit * 2.0; radius: 8; color: root.activePrayer === 'Sunrise' ? Kirigami.Theme.highlightColor : "transparent"; RowLayout { anchors.fill: parent; anchors.leftMargin: Kirigami.Units.largeSpacing; anchors.rightMargin: Kirigami.Units.largeSpacing; Label { text: getPrayerName(root.languageIndex, "Sunrise"); color: parent.parent.color === Kirigami.Theme.highlightColor ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.weight: Font.Bold; font.pointSize: Kirigami.Theme.defaultFont.pointSize } Item { Layout.fillWidth: true } Label { text: root.to12HourTime(root.displayPrayerTimes.Sunrise, Plasmoid.configuration.hourFormat); color: parent.parent.color === Kirigami.Theme.highlightColor ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.pointSize: Kirigami.Theme.defaultFont.pointSize } } }
            Rectangle { width: parent.width; height: Kirigami.Units.gridUnit * 2.0; radius: 8; color: root.activePrayer === 'Dhuhr' ? Kirigami.Theme.highlightColor : "transparent"; RowLayout { anchors.fill: parent; anchors.leftMargin: Kirigami.Units.largeSpacing; anchors.rightMargin: Kirigami.Units.largeSpacing; Label { text: getPrayerName(root.languageIndex, "Dhuhr"); color: parent.parent.color === Kirigami.Theme.highlightColor ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.weight: Font.Bold; font.pointSize: Kirigami.Theme.defaultFont.pointSize } Item { Layout.fillWidth: true } Label { text: root.to12HourTime(root.displayPrayerTimes.Dhuhr, Plasmoid.configuration.hourFormat); color: parent.parent.color === Kirigami.Theme.highlightColor ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.pointSize: Kirigami.Theme.defaultFont.pointSize } } }
            Rectangle { width: parent.width; height: Kirigami.Units.gridUnit * 2.0; radius: 8; color: root.activePrayer === 'Asr' ? Kirigami.Theme.highlightColor : "transparent"; RowLayout { anchors.fill: parent; anchors.leftMargin: Kirigami.Units.largeSpacing; anchors.rightMargin: Kirigami.Units.largeSpacing; Label { text: getPrayerName(root.languageIndex, "Asr"); color: parent.parent.color === Kirigami.Theme.highlightColor ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.weight: Font.Bold; font.pointSize: Kirigami.Theme.defaultFont.pointSize } Item { Layout.fillWidth: true } Label { text: root.to12HourTime(root.displayPrayerTimes.Asr, Plasmoid.configuration.hourFormat); color: parent.parent.color === Kirigami.Theme.highlightColor ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.pointSize: Kirigami.Theme.defaultFont.pointSize } } }
            Rectangle { width: parent.width; height: Kirigami.Units.gridUnit * 2.0; radius: 8; color: root.activePrayer === 'Maghrib' ? Kirigami.Theme.highlightColor : "transparent"; RowLayout { anchors.fill: parent; anchors.leftMargin: Kirigami.Units.largeSpacing; anchors.rightMargin: Kirigami.Units.largeSpacing; Label { text: getPrayerName(root.languageIndex, "Maghrib"); color: parent.parent.color === Kirigami.Theme.highlightColor ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.weight: Font.Bold; font.pointSize: Kirigami.Theme.defaultFont.pointSize } Item { Layout.fillWidth: true } Label { text: root.to12HourTime(root.displayPrayerTimes.Maghrib, Plasmoid.configuration.hourFormat); color: parent.parent.color === Kirigami.Theme.highlightColor ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.pointSize: Kirigami.Theme.defaultFont.pointSize } } }
            Rectangle { width: parent.width; height: Kirigami.Units.gridUnit * 2.0; radius: 8; color: root.activePrayer === 'Isha' ? Kirigami.Theme.highlightColor : "transparent"; RowLayout { anchors.fill: parent; anchors.leftMargin: Kirigami.Units.largeSpacing; anchors.rightMargin: Kirigami.Units.largeSpacing; Label { text: getPrayerName(root.languageIndex, "Isha"); color: parent.parent.color === Kirigami.Theme.highlightColor ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.weight: Font.Bold; font.pointSize: Kirigami.Theme.defaultFont.pointSize } Item { Layout.fillWidth: true } Label { text: root.to12HourTime(root.displayPrayerTimes.Isha, Plasmoid.configuration.hourFormat); color: parent.parent.color === Kirigami.Theme.highlightColor ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.pointSize: Kirigami.Theme.defaultFont.pointSize } } }

            PlasmaComponents.MenuSeparator { width: parent.width; topPadding: Kirigami.Units.smallSpacing; bottomPadding: Kirigami.Units.smallSpacing }
            Button { anchors.horizontalCenter: parent.horizontalCenter; text: i18n("Refresh times"); onClicked: root.fetchTimes() }
        }
    }
}
