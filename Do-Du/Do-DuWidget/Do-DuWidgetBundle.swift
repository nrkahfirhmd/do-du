import SwiftUI
import WidgetKit

@main
struct DoDuWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TimerWidget()
        TimerLiveActivity()
    }
}
