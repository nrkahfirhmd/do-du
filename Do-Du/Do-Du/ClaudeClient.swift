//
//  ClaudeClient.swift
//  Do-Du
//
//  Minimal Messages API client over URLSession (no official Swift SDK).
//  Pure `body(_:)` / `parse(_:)` so `checks/run.sh` can test them offline.
//

import Foundation

/// Just enough JSON to build requests and echo assistant content back unchanged.
enum JSON: Codable, Equatable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
           ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    case null, bool(Bool), number(Double), string(String), array([JSON]), object([String: JSON])

    init(stringLiteral v: String) { self = .string(v) }
    init(integerLiteral v: Int) { self = .number(Double(v)) }
    init(booleanLiteral v: Bool) { self = .bool(v) }
    init(arrayLiteral v: JSON...) { self = .array(v) }
    init(dictionaryLiteral v: (String, JSON)...) { self = .object(Dictionary(v, uniquingKeysWith: { $1 })) }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSON].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSON].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): if n == n.rounded(), abs(n) < 1e15 { try c.encode(Int(n)) } else { try c.encode(n) }
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    subscript(key: String) -> JSON? { if case .object(let o) = self { o[key] } else { nil } }
    var string: String? { if case .string(let s) = self { s } else { nil } }
    var int: Int? { if case .number(let n) = self { Int(n) } else { nil } }
    var array: [JSON]? { if case .array(let a) = self { a } else { nil } }

    func encoded() -> Data {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys  // stable bytes → prompt-cache friendly
        return (try? e.encode(self)) ?? Data()
    }
}

enum ClaudeError: LocalizedError, Equatable {
    case noKey, offline, badKey, busy, refused, invalidResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .noKey: "Add your Claude API key in Settings to use this."
        case .offline: "You're offline. Try again when connected."
        case .badKey: "Claude rejected the API key. Check it in Settings."
        case .busy: "Claude is busy right now. Try again in a minute."
        case .refused: "Claude declined this request."
        case .invalidResponse: "Got an unexpected response from Claude."
        case .http(let code, let msg): "Claude error \(code): \(msg)"
        }
    }
}

struct ClaudeRequest {
    var system: String
    var messages: [JSON]
    var tools: [JSON] = []
    /// `low` for chatty/simple work, `medium` for planning.
    var effort = "low"
    /// JSON schema for structured output (`output_config.format`).
    var schema: JSON?
    var maxTokens = 16000
}

struct ToolUse: Equatable {
    let id: String
    let name: String
    let input: JSON
}

struct ClaudeResponse {
    let content: [JSON]
    let stopReason: String

    var text: String {
        content.filter { $0["type"]?.string == "text" }.compactMap { $0["text"]?.string }.joined()
    }

    var toolUses: [ToolUse] {
        content.compactMap { block in
            guard block["type"]?.string == "tool_use", let id = block["id"]?.string,
                  let name = block["name"]?.string else { return nil }
            return ToolUse(id: id, name: name, input: block["input"] ?? [:])
        }
    }
}

enum ClaudeClient {
    static let model = "claude-opus-5-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let fallbackBeta = "server-side-fallback-2026-07-01"

    static func body(_ r: ClaudeRequest) -> JSON {
        var outputConfig: [String: JSON] = ["effort": .string(r.effort)]
        if let schema = r.schema { outputConfig["format"] = ["type": "json_schema", "schema": schema] }
        var body: [String: JSON] = [
            "model": .string(model),
            "max_tokens": .number(Double(r.maxTokens)),
            // System prompt is stable per feature; cache it.
            "system": [["type": "text", "text": .string(r.system), "cache_control": ["type": "ephemeral"]]],
            "messages": .array(r.messages),
            "output_config": .object(outputConfig),
            // Re-run a declined request on Anthropic's recommended model instead of failing.
            "fallbacks": "default",
        ]
        if !r.tools.isEmpty { body["tools"] = .array(r.tools) }
        return .object(body)
    }

    static func parse(_ data: Data) throws -> ClaudeResponse {
        guard let json = try? JSONDecoder().decode(JSON.self, from: data),
              let content = json["content"]?.array,
              let stop = json["stop_reason"]?.string else { throw ClaudeError.invalidResponse }
        if stop == "refusal" { throw ClaudeError.refused }
        return ClaudeResponse(content: content, stopReason: stop)
    }

    static func send(_ r: ClaudeRequest, key: String? = nil,
                     session: URLSession = .shared) async throws -> ClaudeResponse {
        guard let key = key ?? ClaudeKey.current, !key.isEmpty else { throw ClaudeError.noKey }
        var req = URLRequest(url: endpoint, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue(fallbackBeta, forHTTPHeaderField: "anthropic-beta")
        req.httpBody = body(r).encoded()

        for attempt in 0..<2 {
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await session.data(for: req)
            } catch let e as URLError where [.notConnectedToInternet, .networkConnectionLost,
                                             .timedOut, .cannotFindHost, .cannotConnectToHost].contains(e.code) {
                throw ClaudeError.offline
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200: return try parse(data)
            case 401, 403: throw ClaudeError.badKey
            case 429, 529:
                guard attempt == 0 else { throw ClaudeError.busy }
                let wait = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "retry-after").flatMap(Double.init) ?? 2
                try await Task.sleep(for: .seconds(min(wait, 10)))
            default:
                let message = (try? JSONDecoder().decode(JSON.self, from: data))?["error"]?["message"]?.string
                throw ClaudeError.http(status, message ?? "Request failed")
            }
        }
        throw ClaudeError.busy
    }

    /// Runs the tool-use loop. `messages` is append-only: assistant content goes back unchanged.
    /// Returns the final text.
    static func runTools(_ r: ClaudeRequest, messages: inout [JSON], maxSteps: Int = 8,
                         handle: (ToolUse) async -> (result: String, isError: Bool)) async throws -> String {
        for _ in 0..<maxSteps {
            var req = r
            req.messages = messages
            let res = try await send(req)
            messages.append(["role": "assistant", "content": .array(res.content)])
            guard res.stopReason == "tool_use", !res.toolUses.isEmpty else { return res.text }
            var results: [JSON] = []
            for use in res.toolUses {
                let out = await handle(use)
                results.append(["type": "tool_result", "tool_use_id": .string(use.id),
                                "content": .string(out.result), "is_error": .bool(out.isError)])
            }
            // All results for one turn go back in a single user message.
            messages.append(["role": "user", "content": .array(results)])
        }
        return "I couldn't finish that within the step limit. Try a narrower question."
    }
}
