//
//  SettingsView.swift
//  Events Tracker
//
//  Created by Eddie Gao on 31/3/25.
//

import SwiftUI

struct TelegramChatSelectionState {
    var chats: [TelegramChat]
    var selectedChatID: String
    private(set) var discoveryBotToken: String

    init(
        chats: [TelegramChat] = [],
        selectedChatID: String = "",
        discoveryBotToken: String = ""
    ) {
        self.chats = chats
        self.selectedChatID = selectedChatID
        self.discoveryBotToken = discoveryBotToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func clearIfBotTokenChanged(from oldValue: String, to newValue: String) {
        let oldToken = oldValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let newToken = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard oldToken != newToken else {
            return
        }

        clearDiscoveredChats()
    }

    mutating func applyDiscoveredChats(_ chats: [TelegramChat], botToken: String) {
        self.chats = chats
        selectedChatID = chats.first?.id ?? ""
        discoveryBotToken = botToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func clearAfterDiscoveryFailure() {
        clearDiscoveredChats()
    }

    private mutating func clearDiscoveredChats() {
        chats = []
        selectedChatID = ""
        discoveryBotToken = ""
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: CanvasStore

    @State private var baseURL = ""
    @State private var token = ""
    @State private var lookaheadDays = 14
    @State private var telegramRemindersEnabled = false
    @State private var telegramBotToken = ""
    @State private var telegramChatID = ""
    @State private var telegramReminderWindowHours = 24
    @State private var telegramCheckIntervalMinutes = 30
    @State private var telegramRepeatIntervalHours = 24
    @State private var telegramChatSelection = TelegramChatSelectionState()
    @State private var isLoadingTelegramChats = false
    @State private var isSendingTelegramTest = false
    @State private var autoSyncEnabled = false
    @State private var autoSyncIntervalMinutes = 30
    @State private var downloadCacheLimit: DownloadCacheLimitPreset = .unlimited
    @State private var statusMessage: String?
    @State private var didPopulateFields = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(
                    title: "Settings",
                    subtitle: "Connect your Canvas account, configure reminders, and manage local data."
                )

                Form {
                    Section("Canvas Connection") {
                        TextField("https://school.instructure.com", text: $baseURL)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Personal Access Token", text: $token)
                            .textFieldStyle(.roundedBorder)

                        Stepper(value: $lookaheadDays, in: 7...45) {
                            Text("Look ahead \(lookaheadDays) days for upcoming events")
                        }
                    }

                    Section("Auto Sync") {
                        Toggle("Enable automatic sync while the app is open", isOn: $autoSyncEnabled)

                        Stepper(value: $autoSyncIntervalMinutes, in: 5...240, step: 5) {
                            Text("Sync every \(autoSyncIntervalMinutes) minutes")
                        }
                        .disabled(!autoSyncEnabled)

                        Text("Automatic sync refreshes the dashboard and metadata for cached or offline-priority courses. It does not download file contents.")
                            .foregroundStyle(.secondary)
                    }

                    Section("Telegram Reminders") {
                        Toggle("Enable Telegram reminders", isOn: $telegramRemindersEnabled)

                        SecureField("Bot Token", text: $telegramBotToken)
                            .textFieldStyle(.roundedBorder)

                        TextField("Chat ID", text: $telegramChatID)
                            .textFieldStyle(.roundedBorder)

                        Stepper(value: $telegramReminderWindowHours, in: 1...168) {
                            Text("Remind about assignments due within \(telegramReminderWindowHours) hours")
                        }

                        Stepper(value: $telegramCheckIntervalMinutes, in: 5...240, step: 5) {
                            Text("Check every \(telegramCheckIntervalMinutes) minutes while the app is open")
                        }

                        Stepper(value: $telegramRepeatIntervalHours, in: 1...168) {
                            Text("Repeat the same assignment reminder after \(telegramRepeatIntervalHours) hours")
                        }

                        Text("Reminders only run while Events Tracker is open. Minimized windows still count as open.")
                            .foregroundStyle(.secondary)

                        Button {
                            Task {
                                await loadTelegramChats()
                            }
                        } label: {
                            if isLoadingTelegramChats {
                                ProgressView()
                            } else {
                                Text("Load Recent Telegram Chats")
                            }
                        }
                        .disabled(telegramBotToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingTelegramChats)

                        if !telegramChatSelection.chats.isEmpty {
                            Picker("Recent Chats", selection: $telegramChatSelection.selectedChatID) {
                                ForEach(telegramChatSelection.chats) { chat in
                                    Text(chat.displayName).tag(chat.id)
                                }
                            }

                            Button("Use Selected Chat") {
                                telegramChatID = telegramChatSelection.selectedChatID
                            }
                            .disabled(telegramChatSelection.selectedChatID.isEmpty)
                        }

                        Button {
                            Task {
                                await sendTelegramTestMessage()
                            }
                        } label: {
                            if isSendingTelegramTest {
                                ProgressView()
                            } else {
                                Text("Send Test Message")
                            }
                        }
                        .disabled(
                            telegramBotToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || telegramChatID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || isSendingTelegramTest
                        )
                    }

                    Section("Connect") {
                        Text("Use your school's Canvas root domain. If you paste a URL that already includes `/api/v1`, the app will normalize it.")
                        Text("Generate a personal access token from your Canvas account settings, then save and sync.")
                    }

                    Section("Local Data") {
                        Text("Changing the Canvas URL or token clears the cached dashboard so data from different accounts never mixes together.")

                        Picker("Download Cache Limit", selection: $downloadCacheLimit) {
                            ForEach(DownloadCacheLimitPreset.allCases) { preset in
                                Text(preset.label)
                                    .tag(preset)
                            }
                        }

                        Text("This limit applies to downloaded file contents. Course metadata, preferences, and credentials are not counted.")
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        HStack(spacing: 12) {
                            Button("Save") {
                                _ = saveConfiguration()
                            }

                            Button("Save and Sync") {
                                guard saveConfiguration() else {
                                    return
                                }

                                Task {
                                    await store.refresh()
                                }
                            }
                            .disabled(store.isSyncing)

                            Button("Clear Cached Data", role: .destructive) {
                                store.clearLocalData()
                                statusMessage = "Cached dashboard cleared."
                            }

                            Spacer()
                        }

                        if let statusMessage {
                            Text(statusMessage)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .formStyle(.grouped)
            }
            .padding(24)
        }
        .onAppear {
            populateFieldsIfNeeded()
        }
        .onChange(of: telegramBotToken) { oldValue, newValue in
            telegramChatSelection.clearIfBotTokenChanged(from: oldValue, to: newValue)
        }
    }

    private func populateFieldsIfNeeded() {
        guard !didPopulateFields else {
            return
        }

        baseURL = store.config.normalizedBaseURL.isEmpty ? store.config.baseURL : store.config.normalizedBaseURL
        token = store.config.token
        lookaheadDays = store.config.lookaheadDays
        let telegramConfig = store.config.telegramReminders
        telegramRemindersEnabled = telegramConfig.isEnabled
        telegramBotToken = telegramConfig.botToken
        telegramChatID = telegramConfig.chatID
        telegramChatSelection = TelegramChatSelectionState(selectedChatID: telegramConfig.chatID)
        telegramReminderWindowHours = telegramConfig.normalizedReminderWindowHours
        telegramCheckIntervalMinutes = telegramConfig.normalizedCheckIntervalMinutes
        telegramRepeatIntervalHours = telegramConfig.normalizedRepeatIntervalHours
        autoSyncEnabled = store.config.autoSync.isEnabled
        autoSyncIntervalMinutes = store.config.autoSync.normalizedIntervalMinutes
        downloadCacheLimit = store.config.downloadCacheLimit
        didPopulateFields = true
    }

    private func saveConfiguration() -> Bool {
        do {
            let telegramConfig = TelegramReminderConfig(
                isEnabled: telegramRemindersEnabled,
                botToken: telegramBotToken,
                chatID: telegramChatID,
                reminderWindowHours: telegramReminderWindowHours,
                checkIntervalMinutes: telegramCheckIntervalMinutes,
                repeatIntervalHours: telegramRepeatIntervalHours
            )

            if telegramConfig.isEnabled && !telegramConfig.isComplete {
                statusMessage = TelegramServiceError.incompleteConfiguration.localizedDescription
                return false
            }

            let autoSyncConfig = AutoSyncConfig(
                isEnabled: autoSyncEnabled,
                intervalMinutes: autoSyncIntervalMinutes
            )

            let credentialsChanged = try store.saveConfiguration(
                baseURL: baseURL,
                token: token,
                lookaheadDays: lookaheadDays,
                telegramReminders: telegramConfig,
                downloadCacheLimit: downloadCacheLimit,
                autoSync: autoSyncConfig
            )

            statusMessage = credentialsChanged
                ? "Configuration saved. Cached data was cleared for the new Canvas connection."
                : "Configuration saved."
            return true
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }

    private func loadTelegramChats() async {
        isLoadingTelegramChats = true
        defer {
            isLoadingTelegramChats = false
        }

        do {
            let chats = try await store.discoverTelegramChats(botToken: telegramBotToken)
            telegramChatSelection.applyDiscoveredChats(chats, botToken: telegramBotToken)
            statusMessage = chats.isEmpty
                ? "No recent Telegram chats found. Send a message to your bot, then load chats again."
                : "Loaded \(chats.count) recent Telegram chat\(chats.count == 1 ? "" : "s")."
        } catch {
            telegramChatSelection.clearAfterDiscoveryFailure()
            statusMessage = error.localizedDescription
        }
    }

    private func sendTelegramTestMessage() async {
        isSendingTelegramTest = true
        defer {
            isSendingTelegramTest = false
        }

        do {
            try await store.sendTelegramTestMessage(
                botToken: telegramBotToken,
                chatID: telegramChatID
            )
            statusMessage = "Telegram test message sent."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(CanvasStore())
    }
}
