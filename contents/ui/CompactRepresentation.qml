
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

Item {
    id: root

    implicitWidth: (compactStyle === 1) ? Kirigami.Units.gridUnit * 7 :
    (compactStyle === 3) ? Kirigami.Units.gridUnit * 9 :
    Kirigami.Units.gridUnit * 7

    // --- Properties passed from main.qml ---
    property var prayerTimesData: ({})
    property PlasmoidItem plasmoidItem
    property string nextPrayerName: ""
    property string nextPrayerTime: ""
    property string countdownText: ""
    property int compactStyle: 0 // 0: Normal, 1: Countdown, 2: Toggle, 3: Horizontal

    // --- Properties for language and format ---
    property int languageIndex: 0
    property bool hourFormat: false

    // --- Internal Properties ---
    property bool isPrePrayerAlertActive: false
    property bool toggleViewIsPrayerTime: true
    readonly property int maxCompactLabelPixelSize: Kirigami.Theme.defaultFont.pixelSize
    readonly property int minCompactLabelPixelSize: 7

    // --- Helper function to get localized text ---
    function getRemainingText() {
        return (languageIndex === 1) ? "متبقي" : i18n("After");
    }

    function getTimeLeftText() {
        return (languageIndex === 1) ? "الوقت المتبقي:" : i18n("Time Left:");
    }

    // --- Helper function to parse time string to Date object ---
    function parseTimeToDate(timeString) {
        if (!timeString || timeString === "--:--") return null;

        // Handle both 12-hour and 24-hour formats
        let cleanTime = timeString.replace(/\s*(AM|PM|am|pm)\s*/g, '');
        let parts = cleanTime.split(':');
        if (parts.length < 2) return null;

        let hours = parseInt(parts[0], 10);
        let minutes = parseInt(parts[1], 10);

        // Handle 12-hour format conversion
        if (timeString.toLowerCase().includes('pm') && hours !== 12) {
            hours += 12;
        } else if (timeString.toLowerCase().includes('am') && hours === 12) {
            hours = 0;
        }

        let dateObj = new Date();
        dateObj.setHours(hours);
        dateObj.setMinutes(minutes);
        dateObj.setSeconds(0);
        dateObj.setMilliseconds(0);

        return dateObj;
    }

    // --- Timer for 5-minute pre-prayer alert ---
    Timer {
        id: prePrayerAlertTimer
        interval: 1000 // Check every second
        running: true
        repeat: true
        onTriggered: {
            // Only check if we have valid prayer data
            if (!nextPrayerName || !nextPrayerTime || nextPrayerTime === "--:--") {
                root.isPrePrayerAlertActive = false;
                return;
            }

            let prayerTimeObj = parseTimeToDate(nextPrayerTime);
            if (!prayerTimeObj) {
                root.isPrePrayerAlertActive = false;
                return;
            }

            let now = new Date();

            // Handle Fajr prayer spanning midnight
            if (nextPrayerName === "Fajr" && prayerTimeObj < now) {
                prayerTimeObj.setDate(prayerTimeObj.getDate() + 1);
            }

            // Calculate time difference in milliseconds
            let timeDiff = prayerTimeObj.getTime() - now.getTime();

            // 5 minutes = 5 * 60 * 1000 = 300,000 milliseconds
            let fiveMinutesInMs = 5 * 60 * 1000;

            // Activate alert if between 5 minutes and 0 minutes before prayer
            let newAlertState = (timeDiff > 0 && timeDiff <= fiveMinutesInMs);

            // If alert state changed from active to inactive, explicitly reset background
            if (root.isPrePrayerAlertActive && !newAlertState) {
                alertBackground.color = "transparent";
                gradientBackground.opacity = 0.0;
            }

            root.isPrePrayerAlertActive = newAlertState;
        }
    }

    // --- Timers for Toggle Mode ---
    Timer {
        id: toggleTimer
        interval: 18000
        running: root.compactStyle === 2
        repeat: true
        onTriggered: {
            root.toggleViewIsPrayerTime = false;
            toggleReturnTimer.start();
        }
    }

    Timer {
        id: toggleReturnTimer
        interval: 8000
        repeat: false
        onTriggered: {
            root.toggleViewIsPrayerTime = true;
        }
    }

    // --- Background with subtle pulsing yellow alert ---
    Rectangle {
        id: alertBackground
        anchors.fill: parent
        color: "transparent"
        radius: 4

        // Subtle pulsing yellow animation when alert is active
        SequentialAnimation on color {
            id: subtleFlashAnimation
            loops: Animation.Infinite
            running: root.isPrePrayerAlertActive

            // FIXED: Add proper cleanup when animation stops
            onRunningChanged: {
                if (!running) {
                    alertBackground.color = "transparent";
                }
            }

            ColorAnimation {
                from: "transparent"
                to: Qt.rgba(1.0, 0.84, 0.0, 0.15) // Soft yellow with 15% opacity
                duration: 2000 // Slower transition for subtlety
                easing.type: Easing.InOutSine // Smoother easing
            }
            ColorAnimation {
                from: Qt.rgba(1.0, 0.84, 0.0, 0.15)
                to: "transparent"
                duration: 2000
                easing.type: Easing.InOutSine
            }
        }

        // Very subtle border that appears during alert
        border.width: root.isPrePrayerAlertActive ? 1 : 0
        border.color: Qt.rgba(1.0, 0.84, 0.0, 0.3) // Slightly more visible border

        // Add a subtle shadow effect during alert
        Rectangle {
            id: shadowEffect
            anchors.fill: parent
            color: "transparent"
            radius: parent.radius
            border.width: root.isPrePrayerAlertActive ? 1 : 0
            border.color: Qt.rgba(1.0, 0.84, 0.0, 0.08) // Very subtle outer glow
            anchors.margins: -1
            z: -1
        }
    }

    // --- Alternative gradient background for even more subtlety ---
    Rectangle {
        id: gradientBackground
        anchors.fill: parent
        color: "transparent"
        radius: 4
        visible: root.isPrePrayerAlertActive
        opacity: 0.0

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1.0, 0.84, 0.0, 0.05) }
            GradientStop { position: 0.5; color: Qt.rgba(1.0, 0.84, 0.0, 0.12) }
            GradientStop { position: 1.0; color: Qt.rgba(1.0, 0.84, 0.0, 0.05) }
        }

        // Gentle breathing animation for the gradient
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: root.isPrePrayerAlertActive

            // FIXED: Add proper cleanup when animation stops
            onRunningChanged: {
                if (!running) {
                    gradientBackground.opacity = 0.0;
                }
            }

            NumberAnimation {
                from: 0.0
                to: 1.0
                duration: 3000
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                from: 1.0
                to: 0.0
                duration: 3000
                easing.type: Easing.InOutQuad
            }
        }
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

    // --- Layouts ---
    StackLayout {
        id: layoutSwitcher
        anchors.fill: parent
        anchors.margins: 2 // Small margin to prevent clipping of border
        currentIndex: {
            if (root.compactStyle === 1) return 1; // Countdown view
            if (root.compactStyle === 3) return 2; // Horizontal view
            return 0; // Normal & Toggle view
        }

        // Item 0: Normal & Toggle View
        Label {
            id: normalAndToggleLabel
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pointSize: Kirigami.Theme.defaultFont.pointSize
            fontSizeMode: Text.Fit

            // More subtle text enhancement during alert
            color: root.isPrePrayerAlertActive ?
            Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.9) :
            Kirigami.Theme.textColor
            font.weight: root.isPrePrayerAlertActive ? Font.Medium : Font.Normal

            text: {
                if (root.compactStyle === 2 && !root.toggleViewIsPrayerTime) {
                    return getTimeLeftText() + "\n" + root.countdownText.substring(0, 5);
                } else {
                    return root.nextPrayerName + "\n" + root.nextPrayerTime;
                }
            }
        }

        // Item 1: Countdown View (side-by-side)
        RowLayout {
            id: countdownView
            spacing: Kirigami.Units.largeSpacing
            anchors.centerIn: parent

            Label {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                color: root.isPrePrayerAlertActive ?
                Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.9) :
                Kirigami.Theme.textColor
                font.weight: root.isPrePrayerAlertActive ? Font.Medium : Font.Normal
                text: root.nextPrayerName + "\n" + root.nextPrayerTime
            }

            Rectangle {
                width: 1
                Layout.fillHeight: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                color: root.isPrePrayerAlertActive ?
                Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.9) :
                Kirigami.Theme.textColor
                opacity: 0.4
            }

            Label {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                color: root.isPrePrayerAlertActive ?
                Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.9) :
                Kirigami.Theme.textColor
                font.weight: root.isPrePrayerAlertActive ? Font.Medium : Font.Normal
                text: getRemainingText() + "\n" + root.countdownText.substring(0, 5);
            }
        }

        // Item 2: NEW - Horizontal View (prayer name next to time)
        RowLayout {
            id: horizontalView
            spacing: Kirigami.Units.smallSpacing
            anchors.centerIn: parent

            Label {
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignRight
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                color: root.isPrePrayerAlertActive ?
                Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.9) :
                Kirigami.Theme.textColor
                font.weight: root.isPrePrayerAlertActive ? Font.Medium : Font.Normal
                text: root.nextPrayerName
            }

            Label {
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                color: root.isPrePrayerAlertActive ?
                Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.9) :
                Kirigami.Theme.textColor
                font.weight: root.isPrePrayerAlertActive ? Font.Medium : Font.Normal
                text: root.nextPrayerTime
            }
        }
    }

    // --- Subtle tooltip ---
    ToolTip {
        id: debugTooltip
        visible: mouseArea.containsMouse && root.isPrePrayerAlertActive
        text: {
            if (root.languageIndex === 1) {
                return "تنبيه: باقي 5 دقائق على " + root.nextPrayerName;
            } else {
                return "Alert: " + root.nextPrayerName + " in 5 minutes";
            }
        }
    }
}
