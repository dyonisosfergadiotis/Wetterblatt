//
//  Wetterblatt_WidgetBundle.swift
//  Wetterblatt Widget
//
//  Created by Dyonisos Fergadiotis on 23.04.26.
//

import WidgetKit
import SwiftUI

@main
struct Wetterblatt_WidgetBundle: WidgetBundle {
    var body: some Widget {
        WetterblattCurrentWidget()
        WetterblattHourlyWidget()
        WetterblattPrecipitationWidget()
        WetterblattWeeklyWidget()
        WetterblattWeatherAccessoryWidget()
        WetterblattRainAccessoryWidget()
    }
}
