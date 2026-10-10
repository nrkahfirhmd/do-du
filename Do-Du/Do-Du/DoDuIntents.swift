//
//  DoDuIntents.swift
//  Do-Du
//
//  Phase 3 DD-33: Siri + Shortcuts. Start/stop the timer, add a task.
//  Entities identify tasks by their (Codable) store identifier and
//  resolve gracefully — a deleted task just means "no task".
//  Add creates the task; Siri/Shortcuts confirmation is the checkpoint.
//

import AppIntents
import Foundation
import SwiftData

// MARK: - Entities

nonisolated struct TaskItemEntity: AppEntity {
    /// Base-64 JSON of the task's PersistentIdentifier.
    var id: String
    var title: String
    var projectName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Do-Du Task")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(projectName)")
    }

    static var defaultQuery = TaskItemQuery()

    static func id(for pid: PersistentIdentifier) -> String { storeID(for: pid) }

    static func pid(from id: String) -> PersistentIdentifier? {
        guard let data = Data(base64Encoded: id) else { return nil }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }
}

nonisolated struct TaskItemQuery: EntityQuery {
    nonisolated func entities(for identifiers: [String]) async throws -> [TaskItemEntity] {
        let ids = identifiers.compactMap(TaskItemEntity.pid(from:))
        return await MainActor.run {
            openTasks().filter { ids.contains($0.persistentModelID) }.map(TaskItemEntity.init(task:))
        }
    }

    nonisolated func suggestedEntities() async throws -> [TaskItemEntity] {
        await MainActor.run { Array(openTasks().prefix(5).map(TaskItemEntity.init(task:))) }
    }
}

nonisolated struct ProjectEntity: AppEntity {
    var id: String
    var title: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Do-Du Project")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    static var defaultQuery = ProjectEntityQuery()

    static func id(for pid: PersistentIdentifier) -> String { storeID(for: pid) }
}

private extension ProjectEntity {
    static func pid(from id: String) -> PersistentIdentifier? {
        guard let data = Data(base64Encoded: id) else { return nil }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }
}

nonisolated struct ProjectEntityQuery: EntityQuery {
    nonisolated func entities(for identifiers: [String]) async throws -> [ProjectEntity] {
        await MainActor.run {
            allProjects().filter { identifiers.contains(ProjectEntity.id(for: $0.persistentModelID)) }
                .map { ProjectEntity(id: ProjectEntity.id(for: $0.persistentModelID), title: $0.name) }
        }
    }

    nonisolated func suggestedEntities() async throws -> [ProjectEntity] {
        await MainActor.run {
            allProjects().map { ProjectEntity(id: ProjectEntity.id(for: $0.persistentModelID), title: $0.name) }
        }
    }
}

/// Stable string for a store object across launches (PersistentIdentifier is Codable).
private nonisolated func storeID(for pid: PersistentIdentifier) -> String {
    (try? JSONEncoder().encode(pid)).map { Data($0).base64EncodedString() } ?? ""
}

private extension TaskItemEntity {
    init(task: TaskItem) {
        self.init(id: storeID(for: task.persistentModelID),
                  title: task.title, projectName: task.project?.name ?? "")
    }
}

// MARK: - Store helpers (MainActor: mainContext)

@MainActor
private func openTasks() -> [TaskItem] {
    guard let ctx = try? SharedStore.container().mainContext else { return [] }
    return (try? ctx.fetch(FetchDescriptor<TaskItem>(
        predicate: #Predicate { !$0.isDone },
        sortBy: [SortDescriptor(\.createdAt)]))) ?? []
}

@MainActor
private func allProjects() -> [Project] {
    guard let ctx = try? SharedStore.container().mainContext else { return [] }
    return (try? ctx.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
}

// MARK: - Intents

struct StartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Do-Du Timer"
    static var description = IntentDescription("Starts the timer, optionally on a task.")

    @Parameter(title: "Task") var task: TaskItemEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Start timer\(\.$task)")
    }

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let pid = task.flatMap { TaskItemEntity.pid(from: $0.id) }
        let dialog = await MainActor.run { () -> String in
            guard let ctx = try? SharedStore.container().mainContext else { return "Couldn't open Do-Du data." }
            var target: TaskItem?
            if let pid {
                target = openTasks().first { $0.persistentModelID == pid }
                if target == nil { return "That task is gone. Timer not started." }
            }
            TimerService.start(target, in: ctx)
            if let target {
                return "Timing \(target.title)."
            }
            return "Timer started."
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Do-Du Timer"
    static var description = IntentDescription("Stops the running timer.")

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = await MainActor.run { () -> String in
            guard let ctx = try? SharedStore.container().mainContext else { return "Couldn't open Do-Du data." }
            guard TimerService.current(in: ctx) != nil else { return "No timer is running." }
            TimerService.stop(in: ctx)
            return "Timer stopped."
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Do-Du Task"
    static var description = IntentDescription("Adds a task to a project.")

    @Parameter(title: "Title") var title: String
    @Parameter(title: "Project") var project: ProjectEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$title) to \(\.$project)")
    }

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = project.flatMap { ProjectEntity.pid(from: $0.id) }
        let dialog = await MainActor.run { () -> String in
            guard let ctx = try? SharedStore.container().mainContext else { return "Couldn't open Do-Du data." }
            guard !name.isEmpty else { return "Give the task a title first." }
            let projects = allProjects()
            guard let chosen = pid.flatMap({ id in projects.first { $0.persistentModelID == id } })
                    ?? projects.first(where: { !$0.isArchived }) else {
                return "Create a project in Do-Du first."
            }
            let t = TaskItem(title: name, project: chosen)
            ctx.insert(t)
            try? ctx.save()
            return "Added \(name) to \(chosen.name)."
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Shortcuts

struct DoDuShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartTimerIntent(),
                    phrases: ["Start my \(.applicationName) timer", "Start timing with \(.applicationName)"],
                    shortTitle: "Start Timer", systemImageName: "play.fill")
        AppShortcut(intent: StopTimerIntent(),
                    phrases: ["Stop my \(.applicationName) timer"],
                    shortTitle: "Stop Timer", systemImageName: "stop.fill")
        AppShortcut(intent: AddTaskIntent(),
                    phrases: ["Add a \(.applicationName) task"],
                    shortTitle: "Add Task", systemImageName: "plus")
    }
}
