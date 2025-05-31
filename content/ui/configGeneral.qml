
import QtQuick 2.0
import QtQuick.Controls 2.0
import org.kde.kirigami 2.5 as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_city: cityField.text
    property alias cfg_country: countryField.text
    property alias cfg_notifications: notificationsCheckBox.checked
    property alias cfg_hourFormat: hourFormatCheckBox.checked
    property alias cfg_method: methodField.currentIndex
    property alias cfg_school: schoolField.currentIndex
    property alias cfg_languageIndex: languageField.currentIndex
    property alias cfg_hijriOffset: hijriOffsetSpinBox.value

    // Aliases for all Prayer Time Offsets
    property alias cfg_fajrOffsetMinutes: fajrOffsetSpin.value
    property alias cfg_sunriseOffsetMinutes: sunriseOffsetSpin.value
    property alias cfg_dhuhrOffsetMinutes: dhuhrOffsetSpin.value     // <-- New
    property alias cfg_asrOffsetMinutes: asrOffsetSpin.value         // <-- New
    property alias cfg_maghribOffsetMinutes: maghribOffsetSpin.value // <-- New
    property alias cfg_ishaOffsetMinutes: ishaOffsetSpin.value       // <-- New

    Kirigami.FormLayout {
        anchors.fill: parent

        TextField {
            id: cityField
            Kirigami.FormData.label: i18n("City:")
            placeholderText: i18n("eg. New York")
            text: plasmoid.configuration.city || ""
        }
        TextField {
            id: countryField
            Kirigami.FormData.label: i18n("Country:")
            placeholderText: i18n("eg. United States")
            text: plasmoid.configuration.country || ""
        }
        ComboBox {
            id: methodField
            Kirigami.FormData.label: i18n("Method:")
            model: ["Jafari / Shia Ithna-Ashari", "University of Islamic Sciences, Karachi", "Islamic Society of North America", "Muslim World League", "Umm Al-Qura University, Makkah", "Egyptian General Authority of Survey", "Institute of Geophysics, University of Tehran", "Gulf Region", "Kuwait", "Qatar", "Majlis Ugama Islam Singapura, Singapore", "Union Organization islamic de France", "Diyanet İşleri Başkanlığı, Turkey", "Spiritual Administration of Muslims of Russia", "Moonsighting Committee Worldwide (not working)", "Dubai (experimental)", "Jabatan Kemajuan Islam Malaysia (JAKIM)", "Tunisia", "Algeria", "KEMENAG - Kementerian Agama Republik Indonesia", "Morocco", "Comunidade Islamica de Lisboa", "Ministry of Awqaf, Islamic Affairs and Holy Places, Jordan"]
            currentIndex: plasmoid.configuration.method !== undefined ? plasmoid.configuration.method : 4
        }
        ComboBox {
            id: languageField
            Kirigami.FormData.label: i18n("Language:")
            model: ["English", "العربية"]
            currentIndex: plasmoid.configuration.languageIndex !== undefined ? plasmoid.configuration.languageIndex : 0
        }
        ComboBox {
            id: schoolField
            Kirigami.FormData.label: i18n("School:")
            model: ["Shafi (standard)", "Hanafi"]
            currentIndex: plasmoid.configuration.school !== undefined ? plasmoid.configuration.school : 0
        }
        SpinBox {
            id: hijriOffsetSpinBox
            Kirigami.FormData.label: i18n("Hijri Date Adjustment (days):")
            from: -2
            to: 2
            value: plasmoid.configuration.hijriOffset !== undefined ? plasmoid.configuration.hijriOffset : 0
        }
        SpinBox {
            id: fajrOffsetSpin
            Kirigami.FormData.label: i18n("Fajr Offset (minutes):")
            from: -60
            to: 60
            value: plasmoid.configuration.fajrOffsetMinutes || 0
        }
        SpinBox {
            id: sunriseOffsetSpin
            Kirigami.FormData.label: i18n("Sunrise Offset (minutes):")
            from: -60
            to: 60
            value: plasmoid.configuration.sunriseOffsetMinutes || 0
        }
        // ADDED Dhuhr, Asr, Maghrib, Isha SpinBoxes
        SpinBox {
            id: dhuhrOffsetSpin
            Kirigami.FormData.label: i18n("Dhuhr Offset (minutes):")
            from: -60
            to: 60
            value: plasmoid.configuration.dhuhrOffsetMinutes || 0
        }
        SpinBox {
            id: asrOffsetSpin
            Kirigami.FormData.label: i18n("Asr Offset (minutes):")
            from: -60
            to: 60
            value: plasmoid.configuration.asrOffsetMinutes || 0
        }
        SpinBox {
            id: maghribOffsetSpin
            Kirigami.FormData.label: i18n("Maghrib Offset (minutes):")
            from: -60
            to: 60
            value: plasmoid.configuration.maghribOffsetMinutes || 0
        }
        SpinBox {
            id: ishaOffsetSpin
            Kirigami.FormData.label: i18n("Isha Offset (minutes):")
            from: -60
            to: 60
            value: plasmoid.configuration.ishaOffsetMinutes || 0
        }

        CheckBox {
            id: hourFormatCheckBox
            Kirigami.FormData.label: i18n("12-Hour Format:")
            checked: plasmoid.configuration.hourFormat || false
        }
        CheckBox {
            id: notificationsCheckBox
            Kirigami.FormData.label: i18n("Notifications enabled:")
            checked: plasmoid.configuration.notifications || false
        }
    }
}
