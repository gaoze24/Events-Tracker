//
//  Events_TrackerApp.swift
//  Events Tracker
//
//  Created by Eddie Gao on 24/3/25.
//

import SwiftUI

private enum AppLaunchMode {
    static let uiTestArgument = "--ui-testing"

    case normal
    case uiTests

    static var current: AppLaunchMode {
        ProcessInfo.processInfo.arguments.contains(uiTestArgument) ? .uiTests : .normal
    }
}

@main
struct Events_TrackerApp: App {
    @StateObject private var store: CanvasStore
    private let launchMode: AppLaunchMode

    init() {
        let launchMode = AppLaunchMode.current
        self.launchMode = launchMode
        _store = StateObject(
            wrappedValue: CanvasStore(
                bootstrapMode: launchMode == .uiTests ? .uiTests : .normal
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    guard launchMode == .normal else {
                        return
                    }

                    store.startTelegramReminderService()
                    store.startCacheMaintenance()
                    await store.refreshIfNeeded()
                }
        }
        .defaultSize(width: 1160, height: 860)
    }
}
