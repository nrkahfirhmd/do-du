//
//  ChatView.swift
//  Do-Du
//
//  Ask questions about your own data. Conversation lives in memory only.
//

import SwiftUI
import SwiftData

struct AssistantView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case recap = "Recap", chat = "Chat"
        var id: Self { self }
    }
    @State private var mode = Mode.recap

    var body: some View {
        Group {
            switch mode {
            case .recap: RecapView()
            case .chat: ChatView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }
}

struct ChatView: View {
    struct Line: Identifiable {
        let id = UUID()
        let fromUser: Bool
        let text: String
    }

    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query private var entries: [TimeEntry]
    @Query private var tasks: [TaskItem]
    @State private var lines: [Line] = []
    /// Full API history (append-only; assistant content echoed back unchanged).
    @State private var history: [JSON] = []
    @State private var draft = ""
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    if lines.isEmpty {
                        Text("Ask about your time and tasks, e.g. \"How much deep work did I do last week?\" or \"Which days this month weren't enough?\"")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(lines) { line in
                        Text(line.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: line.fromUser ? .trailing : .leading)
                            .foregroundStyle(line.fromUser ? Color.accentColor : .primary)
                            .id(line.id)
                    }
                    if busy { ProgressView().frame(maxWidth: .infinity) }
                }
                .onChange(of: lines.count) { if let last = lines.last { proxy.scrollTo(last.id) } }
            }
            HStack {
                TextField("Ask Do-Du…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                Button("Send", systemImage: "arrow.up.circle.fill", action: send)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .disabled(draft.isBlank || busy)
            }
            .padding()
        }
        .navigationTitle("Chat")
        .toolbar {
            Button("New Chat", systemImage: "square.and.pencil") { lines = []; history = [] }
                .disabled(lines.isEmpty || busy)
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        draft = ""
        lines.append(Line(fromUser: true, text: text))
        history.append(["role": "user", "content": .string(text)])
        busy = true
        let tools = ChatTools(projects: projects, entries: entries, tasks: tasks)
        Task {
            var messages = history
            do {
                let answer = try await ClaudeClient.runTools(
                    ClaudeRequest(system: Self.system(now: .now), messages: [], tools: ChatTools.definitions),
                    messages: &messages) { tools.run($0) }
                history = messages
                lines.append(Line(fromUser: false, text: answer.trimmingCharacters(in: .whitespacesAndNewlines)))
            } catch {
                // Drop the unanswered question so history stays valid for the next turn.
                history.removeLast()
                lines.append(Line(fromUser: false, text: error.localizedDescription))
            }
            busy = false
        }
    }

    static func system(now: Date) -> String {
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd EEEE"
        return """
            You answer questions about the user's own data in Do-Du, a personal to-do list and work timer. \
            Today is \(day.string(from: DayMath.logicalDate(now))).

            Use the tools for every number; never guess or do your own totals when a tool can return them. \
            Tools are read-only: if asked to change data, say the user can do it in the app. \
            "No project" time is tracked but does not count toward targets. \
            Answer briefly in plain text.
            """
    }
}
