//
//  CanvasConfigManager.swift
//  Events Tracker
//
//  Created by Eddie Gao on 1/4/25.
//

import Foundation

final class CanvasConfigManager {
    static let shared = CanvasConfigManager()

    private let configURL: URL
    private let tokenStore: CanvasTokenStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configURL: URL? = nil, tokenStore: CanvasTokenStore = KeychainCanvasTokenStore()) {
        self.tokenStore = tokenStore
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()

        if let configURL {
            self.configURL = configURL
            return
        }

        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let appDirectory = baseDirectory.appendingPathComponent("EventsTracker", isDirectory: true)

        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.configURL = appDirectory.appendingPathComponent("canvas-config.json")
    }

    func saveConfig(_ config: CanvasConfig) throws {
        try tokenStore.setToken(config.trimmedToken, for: .canvasAccessToken)
        try tokenStore.setToken(config.telegramReminders.trimmedBotToken, for: .telegramBotToken)

        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    func loadConfig() -> CanvasConfig {
        guard let data = try? Data(contentsOf: configURL) else {
            return CanvasConfig()
        }

        var config = (try? decoder.decode(CanvasConfig.self, from: data)) ?? CanvasConfig()
        let legacyCanvasToken = config.trimmedToken
        let legacyTelegramBotToken = config.telegramReminders.trimmedBotToken
        var didMigrateLegacyToken = false
        var canRewriteConfig = true

        if let storedCanvasToken = try? tokenStore.token(for: .canvasAccessToken), !storedCanvasToken.isEmpty {
            config.token = storedCanvasToken
        } else if !legacyCanvasToken.isEmpty {
            do {
                try tokenStore.setToken(legacyCanvasToken, for: .canvasAccessToken)
                didMigrateLegacyToken = true
            } catch {
                canRewriteConfig = false
            }
        }

        if let storedTelegramBotToken = try? tokenStore.token(for: .telegramBotToken), !storedTelegramBotToken.isEmpty {
            config.telegramReminders.botToken = storedTelegramBotToken
        } else if !legacyTelegramBotToken.isEmpty {
            do {
                try tokenStore.setToken(legacyTelegramBotToken, for: .telegramBotToken)
                didMigrateLegacyToken = true
            } catch {
                canRewriteConfig = false
            }
        }

        if didMigrateLegacyToken && canRewriteConfig {
            try? writeConfig(config)
        }

        return config
    }

    private func writeConfig(_ config: CanvasConfig) throws {
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }
}
