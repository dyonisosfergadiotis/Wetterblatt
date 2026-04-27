import Foundation

enum WeatherDateFormatting {
    static let germanLocale = Locale(identifier: "de_DE")

    static func string(
        from date: Date,
        format: String,
        timeZone: TimeZone,
        capitalized: Bool = false
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = germanLocale
        formatter.timeZone = timeZone
        formatter.dateFormat = format

        let value = formatter.string(from: date)
        return capitalized ? value.capitalized : value
    }

    static func time(_ date: Date, timeZone: TimeZone) -> String {
        string(from: date, format: "HH:mm", timeZone: timeZone)
    }

    static func shortDayMonth(_ date: Date, timeZone: TimeZone) -> String {
        string(from: date, format: "d. MMM", timeZone: timeZone)
    }

    static func longDayMonth(_ date: Date, timeZone: TimeZone) -> String {
        string(from: date, format: "EEEE, d. MMMM", timeZone: timeZone, capitalized: true)
    }

    static func topBarDate(_ date: Date, timeZone: TimeZone) -> String {
        string(from: date, format: "EEE, d. MMM", timeZone: timeZone)
    }

    static func hourLabel(for date: Date, relativeTo referenceDate: Date, timeZone: TimeZone) -> String {
        let format = Calendar.weatherCalendar(timeZone: timeZone)
            .isDate(date, equalTo: referenceDate, toGranularity: .hour)
            ? "HH:mm"
            : "HH"

        return string(from: date, format: format, timeZone: timeZone)
    }

    static func shortWeekday(_ date: Date, timeZone: TimeZone) -> String {
        string(from: date, format: "EEE", timeZone: timeZone, capitalized: true)
    }
}
