//
//  CSVExport.swift
//  Do-Du
//

import SwiftUI
import UniformTypeIdentifiers

enum TimeEntryCSV {
    static func make(_ entries: [TimeEntry], now: Date = .now, calendar: Calendar = .current) -> String {
        let day = DateFormatter()
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        let stamp = ISO8601DateFormatter()
        stamp.timeZone = calendar.timeZone
        let header = "date,start,end,minutes,project,task,category"
        let rows = entries.sorted { $0.start < $1.start }.map { e in
            [day.string(from: DayMath.logicalDate(e.start, calendar: calendar)),
             stamp.string(from: e.start),
             e.end.map(stamp.string) ?? "",
             String(Int(e.duration(now: now) / 60)),
             e.effectiveProject?.name ?? "",
             e.task?.title ?? "",
             e.task?.category?.name ?? ""].map(field).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    /// RFC 4180: quote when needed, double inner quotes.
    nonisolated static func field(_ s: String) -> String {
        s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" })
            ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String

    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
