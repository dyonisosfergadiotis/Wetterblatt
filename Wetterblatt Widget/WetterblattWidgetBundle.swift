import WidgetKit
import SwiftUI

@main
struct WetterblattWidgetBundle: WidgetBundle {
    var body: some Widget {
        WetterblattCurrentWidget()
        WetterblattHourlyWidget()
        WetterblattPrecipitationWidget()
        WetterblattWeeklyWidget()
        WetterblattWeatherAccessoryWidget()
        WetterblattRainAccessoryWidget()
    }
}
