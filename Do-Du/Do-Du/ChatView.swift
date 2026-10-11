//
//  ChatView.swift
//  Do-Du
//
//  Ask questions about your own data. Conversation lives in memory only.
//

import SwiftUI
import SwiftData

struct AssistantView: View {
    enum Mode: String, CaseIterable, Identifiable, Codable {
        case recap = "Recap", chat = "Chat"
        var id: Self { self }
    }
    @AppStorage("assistantMode") private var mode = Mode.recap

    var body: some View {
        #if os(macOS)
        // Mac: Recap beside Chat.
        HStack(spacing: 14) {
            RecapView().frame(maxWidth: .infinity)
            ChatView().frame(maxWidth: .infinity)
        }
        .background(DD.page)
        #else
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
        #endif
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
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if lines.isEmpty {
                            Text("Ask about your time and tasks, e.g. \"How much deep work did I do last week?\" or \"Which days this month weren't enough?\"")
                                .font(.subheadline).foregroundStyle(DD.ink3)
                                .padding(.horizontal, 16).padding(.top, 8)
                        }
                        ForEach(lines) { line in
                            ChatBubble(text: line.text, fromUser: line.fromUser).id(line.id)
                        }
                        if busy { ProgressView().frame(maxWidth: .infinity) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
                .background(DD.page)
                .onChange(of: lines.count) { if let last = lines.last { proxy.scrollTo(last.id) } }
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask Do-Du…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(DD.surface, in: .dd(22))
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(draft.isBlank || busy ? DD.disabled : DD.forestFill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send")
                .disabled(draft.isBlank || busy)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(DD.page)
        }
        #if !os(macOS)
        .navigationTitle("Chat")   // Mac shows both side by side under "Assistant"
        #endif
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

/// User messages: forest with white text, right. Replies: surface, left.
struct ChatBubble: View {
    let text: String
    let fromUser: Bool

    var body: some View {
        Text(text)
            .textSelection(.enabled)
            .font(.body)
            .foregroundStyle(fromUser ? Color.white : DD.ink)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(fromUser ? DD.forestFill : DD.surface, in: .dd(20))
            .frame(maxWidth: 300, alignment: fromUser ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: fromUser ? .trailing : .leading)
    }
}
