//
//  SharedStore.swift
//  Do-Du
//
//  Locates the SwiftData store inside the App Group container so the
//  widget extension reads the same data as the app. Moves a pre-group
//  store there once.
//

import Foundation
import SwiftData

enum SharedStore {
    static let appGroupID = "group.com.kv.Do-Du"
    static let fileName = "Do-Du.store"

    static var groupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Store URL inside `group`, or nil when the App Group is unavailable
    /// (e.g. unsigned builds) — callers then fall back to the default location.
    static func storeURL(groupURL: URL?) -> URL? {
        groupURL?.appendingPathComponent(fileName, isDirectory: false)
    }

    /// Where SwiftData kept the store before DD-30 (App Group).
    static func legacyStoreURL(appSupport: URL) -> URL {
        appSupport.appendingPathComponent("default.store", isDirectory: false)
    }

    /// Moves `default.store*` into the group container once. Returns the
    /// group URL when a move happened, nil otherwise.
    @discardableResult
    static func migrateIfNeeded(fileManager: FileManager = .default) -> URL? {
        guard let group = groupURL,
              let target = storeURL(groupURL: group),
              let support = try? fileManager.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: false) else { return nil }
        return migrate(from: legacyStoreURL(appSupport: support), to: target, fileManager: fileManager)
    }

    /// App Store configuration: group container with CloudKit, falling back
    /// to the default location when the App Group is unavailable.
    static func modelConfiguration() -> ModelConfiguration {
        let schema = Schema(allModels)
        migrateIfNeeded()
        if let url = storeURL(groupURL: groupURL) {
            return ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .automatic)
        }
        return ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
    }

    /// Opens the same store the app uses. Used by Siri/Shortcuts intents.
    static func container() throws -> ModelContainer {
        try ModelContainer(for: Schema(allModels), configurations: [modelConfiguration()])
    }

    /// Pure move helper: `from` (+ `-wal`/`-shm`) → `to`. Nil when skipped.
    @discardableResult
    static func migrate(from legacy: URL, to target: URL, fileManager: FileManager = .default) -> URL? {
        guard !fileManager.fileExists(atPath: target.path),
              fileManager.fileExists(atPath: legacy.path) else { return nil }
        do {
            try fileManager.createDirectory(at: target.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
            try fileManager.moveItem(at: legacy, to: target)
            for suffix in ["-wal", "-shm"] {
                let src = URL(fileURLWithPath: legacy.path + suffix)
                if fileManager.fileExists(atPath: src.path) {
                    try fileManager.moveItem(at: src, to: URL(fileURLWithPath: target.path + suffix))
                }
            }
            return target
        } catch {
            return nil
        }
    }
}
