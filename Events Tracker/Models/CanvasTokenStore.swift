//
//  CanvasTokenStore.swift
//  Events Tracker
//

import Foundation
import Security

enum CanvasTokenKind: String, Hashable {
    case canvasAccessToken
    case telegramBotToken
}

protocol CanvasTokenStore {
    func token(for kind: CanvasTokenKind) throws -> String?
    func setToken(_ token: String?, for kind: CanvasTokenKind) throws
}

struct KeychainCanvasTokenStore: CanvasTokenStore {
    private let service: String

    init(service: String = "Fluctlight.Events-Tracker.tokens") {
        self.service = service
    }

    func token(for kind: CanvasTokenKind) throws -> String? {
        var query = baseQuery(for: kind)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainCanvasTokenStoreError.unhandledStatus(status)
        }

        guard let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func setToken(_ token: String?, for kind: CanvasTokenKind) throws {
        let trimmedToken = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmedToken.isEmpty else {
            try deleteToken(for: kind)
            return
        }

        let data = Data(trimmedToken.utf8)
        let query = baseQuery(for: kind)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var attributes = query
            attributes[kSecValueData as String] = data
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)

            guard addStatus == errSecSuccess else {
                throw KeychainCanvasTokenStoreError.unhandledStatus(addStatus)
            }
        default:
            throw KeychainCanvasTokenStoreError.unhandledStatus(updateStatus)
        }
    }

    private func deleteToken(for kind: CanvasTokenKind) throws {
        let status = SecItemDelete(baseQuery(for: kind) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainCanvasTokenStoreError.unhandledStatus(status)
        }
    }

    private func baseQuery(for kind: CanvasTokenKind) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: kind.rawValue
        ]
    }
}

enum KeychainCanvasTokenStoreError: LocalizedError {
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}
