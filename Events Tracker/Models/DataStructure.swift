//
//  Course.swift
//  Events Tracker
//
//  Created by Eddie Gao on 1/4/25.
//

import Foundation

struct Course: Codable, Identifiable {
    let id: Int
    let name: String
}

struct Assignment: Codable, Identifiable {
    let id: Int
    let name: String
    let dueAt: String
}

struct CanvasConfig: Codable {
    let baseURL: String
    let token: String
}
