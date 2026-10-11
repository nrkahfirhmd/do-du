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
    /// Off keeps data on this device only. Read when the container opens, so a change applies next launch.
    static let iCloudKey = "iCloudSyncOn"
    static var iCloudOn: Bool { UserDefaults.standard.object(forKey: iCloudKey) as? Bool ?? true }
    /// What the open container uses (the setting may have changed since).
    static let iCloudOnAtLaunch = iCloudOn

    /// The App Group folder, or nil when this build can't use it. On macOS the system
    /// returns a path even without the entitlement (unsigned/ad-hoc builds), so check access.
    static var groupURL: URL? {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
              FileManager.default.isWritableFile(atPath: url.path) else { return nil }
        return url
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
        let cloud: ModelConfiguration.CloudKitDatabase = iCloudOnAtLaunch ? .automatic : .none
        migrateIfNeeded()
        if let url = storeURL(groupURL: groupURL) {
            return ModelConfiguration(schema: schema, url: url, cloudKitDatabase: cloud)
        }
        return ModelConfiguration(schema: schema, cloudKitDatabase: cloud)
    }

    /// The one container for this process: app UI, timers and Siri/Shortcuts intents.
    /// Never open a second container on this store in the same process: two
    /// CloudKit-mirrored containers conflict, and objects fetched from one context
    /// can't be related to objects inserted in another.
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: Schema(allModels), configurations: [modelConfiguration()])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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
