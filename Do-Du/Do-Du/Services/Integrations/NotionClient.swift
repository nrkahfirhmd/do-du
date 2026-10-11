import Foundation
import SwiftData

enum NotionError: LocalizedError, Equatable {
    case noToken, noDatabase, offline, badToken, notFound, rateLimited
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .noToken: "Add your Notion token in Settings to import."
        case .noDatabase: "Add your Notion database ID in Settings to import."
        case .offline: "You're offline. Try again when connected."
        case .badToken: "Notion rejected the token. Check it in Settings."
        case .notFound: "Database not found. Check the ID and invite the integration to the page."
        case .rateLimited: "Notion is busy right now. Try again in a minute."
        case .http(let code, let msg): "Notion error \(code): \(msg)"
        }
    }
}

struct NotionPage: Equatable {
    var id: String
    var title: String
    var isDone: Bool
    var dueDate: Date?
    var projectName: String?
}

enum NotionClient: TaskSource {
    static let id = "notion"
    static let displayName = "Notion"
    static let databaseKey = "notionDatabaseID"
    // Must be a released Notion-Version.
    private static let apiVersion = "2022-06-28"
    private static let endpoint = URL(string: "https://api.notion.com/v1")!
    private static let pageSize = 100
    private static let doneNames = ["done", "completed", "complete"]

    static var databaseID: String {
        UserDefaults.standard.string(forKey: databaseKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func isConfigured() -> Bool {
        NotionKey.current?.isEmpty == false && !databaseID.isEmpty
    }

    /// Accepts a bare ID (plain or hyphenated) or a notion.so URL.
    static func normalizeDatabaseID(_ s: String) -> String {
        let base = s.split(separator: "?").first.map(String.init) ?? s
        if let m = base.range(of: "[0-9a-fA-F]{32}", options: .regularExpression) {
            return String(base[m]).lowercased()
        }
        let hex = base.filter(\.isHexDigit)
        return hex.count == 32 ? hex.lowercased() : ""
    }

    static func queryBody(cursor: String?) -> JSON {
        var o: [String: JSON] = ["page_size": .number(Double(pageSize))]
        if let cursor { o["start_cursor"] = .string(cursor) }
        return .object(o)
    }

    static func error(status: Int, json: JSON?) -> NotionError {
        let code = json?["code"]?.string ?? ""
        let message = json?["message"]?.string ?? "Request failed"
        switch (status, code) {
        case (401, _), (403, _): return .badToken
        case (404, _): return .notFound
        case (429, _), (_, "rate_limited"): return .rateLimited
        default: return .http(status, message)
        }
    }

    struct QueryResult: Equatable {
        var pages: [NotionPage]
        var nextCursor: String?
    }

    static func parse(_ data: Data, calendar: Calendar = .current) throws -> QueryResult {
        guard let json = try? JSONDecoder().decode(JSON.self, from: data),
              let results = json["results"]?.array else {
            throw NotionError.http(0, "Bad response")
        }
        let pages = results.compactMap { r -> NotionPage? in
            guard let id = r["id"]?.string, let props = r["properties"] else { return nil }
            return page(id: id, properties: props, calendar: calendar)
        }
        let cursor = json["has_more"]?.bool == true ? json["next_cursor"]?.string : nil
        return QueryResult(pages: pages, nextCursor: cursor)
    }

    static func page(id: String, properties: JSON, calendar: Calendar = .current) -> NotionPage? {
        guard let props = properties.object else { return nil }
        let byType = { (t: String) in props.values.filter { $0["type"]?.string == t } }

        let title = byType("title").compactMap { p in
            p["title"]?.array?.compactMap { $0["plain_text"]?.string }.joined()
        }.first(where: { !$0.isEmpty }) ?? ""
        guard !title.isEmpty else { return nil }

        let done: Bool = if let check = byType("checkbox").first {
            check["checkbox"]?.bool ?? false
        } else if let status = byType("status").first?.dig("status", "name") {
            doneNames.contains(status.lowercased())
        } else { false }

        let due = byType("date").compactMap { $0["date"]?["start"]?.string }.first.flatMap {
            parseDate($0, calendar: calendar)
        }

        let project = byType("select").compactMap { $0["select"]?["name"]?.string }.first
            ?? byType("rich_text").compactMap { p in
                p["rich_text"]?.array?.compactMap { $0["plain_text"]?.string }.joined()
            }.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

        return NotionPage(id: id, title: title, isDone: done, dueDate: due, projectName: project)
    }

    static func parseDate(_ s: String, calendar: Calendar = .current) -> Date? {
        if s.count == 10 {
            let f = DateFormatter()
            f.calendar = calendar
            f.timeZone = calendar.timeZone
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"
            return f.date(from: s)
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: s).map { calendar.startOfDay(for: $0) }
            ?? ISO8601DateFormatter().date(from: s).map { calendar.startOfDay(for: $0) }
    }

    // MARK: - Transport

    static func fetchDrafts() async throws -> [ExternalDraft] {
        guard let token = NotionKey.current, !token.isEmpty else { throw NotionError.noToken }
        let db = databaseID
        guard !db.isEmpty else { throw NotionError.noDatabase }
        var out: [NotionPage] = []
        var cursor: String? = nil
        repeat {
            let result = try await queryPage(databaseID: db, token: token, cursor: cursor)
            out += result.pages
            cursor = result.nextCursor
        } while cursor != nil
        return out.map {
            ExternalDraft(source: id, externalID: $0.id, title: $0.title,
                          isDone: $0.isDone, dueDate: $0.dueDate, projectName: $0.projectName)
        }
    }

    private static func queryPage(databaseID: String, token: String, cursor: String?,
                                  session: URLSession = .shared) async throws -> QueryResult {
        var req = URLRequest(url: endpoint.appendingPathComponent("databases/\(databaseID)/query"),
                             timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        req.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        req.httpBody = queryBody(cursor: cursor).encoded()

        let data: Data
        let status: Int
        do {
            let (d, r) = try await session.data(for: req)
            data = d
            status = (r as? HTTPURLResponse)?.statusCode ?? 0
        } catch let e as URLError where [.notConnectedToInternet, .networkConnectionLost,
                                         .timedOut, .cannotFindHost, .cannotConnectToHost].contains(e.code) {
            throw NotionError.offline
        }
        guard status == 200 else {
            throw error(status: status, json: try? JSONDecoder().decode(JSON.self, from: data))
        }
        return try parse(data)
    }
}

private extension JSON {
    func dig(_ keys: String...) -> String? {
        var node: JSON? = self
        for k in keys { node = node?[k] }
        return node?.string
    }
}
