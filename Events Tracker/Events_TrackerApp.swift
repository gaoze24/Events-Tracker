//
//  Events_TrackerApp.swift
//  Events Tracker
//
//  Created by Eddie Gao on 24/3/25.
//

import SwiftUI

/// Hard limits on how small the main window may be scaled before the layout
/// (dashboard stat cards, sidebar, multi-column content) starts breaking.
enum AppWindowMetrics {
    static let minWidth: CGFloat = 960
    static let minHeight: CGFloat = 640
}

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
                .frame(
                    minWidth: AppWindowMetrics.minWidth,
                    minHeight: AppWindowMetrics.minHeight
                )
                .task {
                    guard launchMode == .normal else {
                        return
                    }

                    store.startTelegramReminderService()
                    store.startCacheMaintenance()
                    store.startAutoSync()
                    await store.refreshIfNeeded()
                }
        }
        .defaultSize(width: 1160, height: 860)
        .windowResizability(.contentMinSize)
    }
}
