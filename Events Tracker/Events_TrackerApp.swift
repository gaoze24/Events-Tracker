//
//  Events_TrackerApp.swift
//  Events Tracker
//
//  Created by Eddie Gao on 24/3/25.
//

import SwiftUI

@main
struct Events_TrackerApp: App {
    @StateObject private var store = CanvasStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    store.startTelegramReminderService()
                    await store.refreshIfNeeded()
                }
        }
        .defaultSize(width: 1160, height: 860)
    }
}
