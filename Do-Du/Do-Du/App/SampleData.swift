import Foundation
import SwiftData

extension SharedStore {
    /// In-memory store for `#Preview`, with sample data in DEBUG.
    @MainActor static var preview: ModelContainer {
        let config = ModelConfiguration(schema: Schema(allModels), isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: Schema(allModels), configurations: [config])
        #if DEBUG
        SampleData.seed(container.mainContext)
        #endif
        return container
    }
}

#if DEBUG

enum SampleData {
    static func seedIfRequested(_ context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "seedSampleData"),
              (try? context.fetchCount(FetchDescriptor<Project>())) == 0 else { return }
        seed(context)
    }

    static func seed(_ context: ModelContext) {

        let deep = Category(name: "Deep Work", colorName: "sage")
        let admin = Category(name: "Admin", colorName: "slate")
        let dodu = Project(name: "Do-Du", colorName: "forest", dailyTargetMinutes: 180, activeWeekdaysMask: Weekdays.all)
        let client = Project(name: "Client X", colorName: "moss", dailyTargetMinutes: 120, activeWeekdaysMask: Weekdays.all)
        [deep, admin].forEach(context.insert)
        [dodu, client].forEach(context.insert)

        let tasks = [
            TaskItem(title: "Build Today view", project: dodu, category: deep),
            TaskItem(title: "Write stats charts", project: dodu, category: deep),
            TaskItem(title: "Invoice October", project: client, category: admin),
            TaskItem(title: "Review designs", project: client, category: deep),
        ]
        tasks[2].dueDate = Calendar.current.startOfDay(for: .now)
        tasks[0].estimateMinutes = 90
        tasks.forEach(context.insert)

        let cal = Calendar.current
        for back in 1...6 {
            let day = cal.startOfDay(for: cal.date(byAdding: .day, value: -back, to: .now)!)
            for (i, task) in tasks.enumerated() {
                let start = day.addingTimeInterval(TimeInterval(9 + i * 2) * 3600)
                let minutes = Double(30 + (back * 17 + i * 23) % 90)
                context.insert(TimeEntry(task: task, start: start, end: start.addingTimeInterval(minutes * 60)))
            }
        }
        context.insert(TimeEntry(task: tasks[1], start: .now.addingTimeInterval(-50 * 60), end: .now.addingTimeInterval(-10 * 60)))
        context.insert(TimeEntry(task: tasks[0], start: .now.addingTimeInterval(-9 * 60)))
        try? context.save()
    }
}
#endif
