//
//  DoDuWidgetBundle.swift
//  Do-Du
//

import SwiftUI
import WidgetKit

@main
struct DoDuWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TimerLiveActivity()
    }
}
