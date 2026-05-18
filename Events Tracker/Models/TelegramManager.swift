//
//  TelegramManager.swift
//  Events Tracker
//

import Foundation

enum TelegramServiceError: LocalizedError {
    case incompleteConfiguration
    case invalidBotToken
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .incompleteConfiguration:
            return "Add a Telegram bot token and chat before enabling reminders."
        case .invalidBotToken:
            return "Telegram bot token is invalid. Check the token from BotFather and try again."
        case .requestFailed(let message):
            return "Telegram request failed: \(message)"
        case .invalidResponse:
            return "Telegram returned an unexpected response."
        }
    }
}

struct TelegramChat: Identifiable, Hashable {
    let id: String
    let title: String

    var displayName: String {
        title.isEmpty ? id : "\(title) (\(id))"
    }
}

final class TelegramManager {
    static let shared = TelegramManager()

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchRecentChats(botToken: String) async throws -> [TelegramChat] {
        let token = botToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw TelegramServiceError.incompleteConfiguration
        }

        let response: TelegramResponse<[TelegramUpdate]> = try await request(
            botToken: token,
            method: "getUpdates",
            queryItems: []
        )

        var chatsByID: [String: TelegramChat] = [:]
        for update in response.result {
            guard let chat = update.message?.chat ?? update.channelPost?.chat else {
                continue
            }

            chatsByID[String(chat.id)] = TelegramChat(
                id: String(chat.id),
                title: chat.displayTitle
            )
        }

        return chatsByID.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func sendMessage(botToken: String, chatID: String, text: String) async throws {
        let token = botToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatID = chatID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !chatID.isEmpty else {
            throw TelegramServiceError.incompleteConfiguration
        }

        let _: TelegramResponse<TelegramMessage> = try await request(
            botToken: token,
            method: "sendMessage",
            formItems: [
                URLQueryItem(name: "chat_id", value: chatID),
                URLQueryItem(name: "text", value: text),
                URLQueryItem(name: "disable_web_page_preview", value: "false")
            ]
        )
    }

    private func request<T: Decodable>(
        botToken: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        formItems: [URLQueryItem] = []
    ) async throws -> TelegramResponse<T> {
        guard var components = URLComponents(string: "https://api.telegram.org/bot\(botToken)/\(method)") else {
            throw TelegramServiceError.invalidBotToken
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw TelegramServiceError.invalidBotToken
        }

        var request = URLRequest(url: url)
        if !formItems.isEmpty {
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.formEncodedBody(from: formItems)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TelegramServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorResponse = try? decoder.decode(TelegramErrorResponse.self, from: data)
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 404 {
                throw TelegramServiceError.invalidBotToken
            }

            throw TelegramServiceError.requestFailed(errorResponse?.description ?? "HTTP \(httpResponse.statusCode)")
        }

        do {
            let decoded = try decoder.decode(TelegramResponse<T>.self, from: data)
            guard decoded.ok else {
                throw TelegramServiceError.requestFailed(decoded.description ?? "Unknown Telegram error")
            }

            return decoded
        } catch let error as TelegramServiceError {
            throw error
        } catch {
            throw TelegramServiceError.invalidResponse
        }
    }

    private static func formEncodedBody(from items: [URLQueryItem]) -> Data? {
        var components = URLComponents()
        components.queryItems = items
        return components.percentEncodedQuery?.data(using: .utf8)
    }
}

private struct TelegramResponse<T: Decodable>: Decodable {
    let ok: Bool
    let result: T
    let description: String?
}

private struct TelegramErrorResponse: Decodable {
    let ok: Bool
    let description: String?
}

private struct TelegramUpdate: Decodable {
    let message: TelegramMessage?
    let channelPost: TelegramMessage?

    enum CodingKeys: String, CodingKey {
        case message
        case channelPost = "channel_post"
    }
}

private struct TelegramMessage: Decodable {
    let chat: TelegramChatPayload
}

private struct TelegramChatPayload: Decodable {
    let id: Int64
    let type: String?
    let title: String?
    let username: String?
    let firstName: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case username
        case firstName = "first_name"
        case lastName = "last_name"
    }

    var displayTitle: String {
        if let title, !title.isEmpty {
            return title
        }

        if let username, !username.isEmpty {
            return "@\(username)"
        }

        return [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
