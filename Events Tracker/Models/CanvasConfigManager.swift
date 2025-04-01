//
//  CanvasConfigManager.swift
//  Events Tracker
//
//  Created by Eddie Gao on 1/4/25.
//

import Foundation

class CanvasConfigManager {
    static let shared = CanvasConfigManager()
    
    private init() { }
    
    private let configFileName = "canvasConfig.json"
    
    func saveConfig(_ config: CanvasConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        let url = try getConfigFileURL()
        try data.write(to: url)
    }
    
    func loadConfig() throws -> CanvasConfig {
        let url = try getConfigFileURL()
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CanvasConfig.self, from: data)
    }
    
    private func getConfigFileURL() throws -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(configFileName)
    }
}
