//
//  InboxExample/InboxExample/App/AppModel.swift
//  InboxExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import MobileMessaging

/// Settings entered on the Settings screen and kept in UserDefaults, except the JWT secret key, which stays in memory.
///
/// A real app hardcodes (and obfuscates) its Application Code and gets JWTs from its own backend instead.
struct ExampleSettings: Codable, Equatable {
    enum Authorization: String, Codable, CaseIterable {
        /// Application Code authorization. Sandbox applications only.
        case applicationCode
        /// JWT signed on the device. Testing only: never ship the secret key in an app.
        case jwt
    }

    var applicationCode = ""
    /// Leave empty for the default Infobip base URL.
    var baseUrl = ""
    var authorization = Authorization.applicationCode
    var jwtKeyId = ""
    var jwtSecretKeyHex = ""
    /// Topics offered as filters on the inbox screen, comma separated. Topics are defined per application.
    var topics = ""

    var topicList: [String] {
        return topics.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private enum CodingKeys: String, CodingKey {
        case applicationCode, baseUrl, authorization, jwtKeyId, topics
    }

    private static let key = "com.infobip.inbox.example.settings"

    static func load() -> ExampleSettings {
        return UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(ExampleSettings.self, from: $0) } ?? ExampleSettings()
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}

/// Whose inbox is shown and how its requests are authorized. The inbox screen reloads whenever it changes.
struct InboxUser: Equatable {
    let externalUserId: String
    let authorization: ExampleSettings.Authorization
    let applicationCode: String
    let jwtKeyId: String
    let jwtSecretKeyHex: String

    /// The JWT for fetching and deleting, or `nil` for Application Code authorization.
    ///
    /// In your app, request the token from your backend instead: it authenticates the signed-in user and signs a
    /// short-lived JWT with `sub` set to their External User ID. Reuse it until it expires, and request a new one
    /// when a request fails with `UNAUTHORIZED`.
    func token() throws -> String? {
        switch authorization {
        case .applicationCode:
            return nil
        case .jwt:
            return try JWTSigner(applicationCode: applicationCode, keyId: jwtKeyId, secretKeyHex: jwtSecretKeyHex).sign(externalUserId: externalUserId)
        }
    }
}

/// SDK setup and personalization.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var settings = ExampleSettings.load()
    @Published private(set) var isSdkStarted = false
    /// The Application Code or base URL was changed. They take effect after the app is relaunched.
    @Published private(set) var requiresRelaunch = false
    @Published private(set) var pushRegistrationId: String?
    @Published private(set) var externalUserId: String?

    /// `nil` until the SDK is started, registered for push notifications and personalized with an External User ID.
    /// Inbox messages are stored only for users with an External User ID.
    var inboxUser: InboxUser? {
        guard isSdkStarted, !requiresRelaunch, pushRegistrationId != nil, let externalUserId = externalUserId else {
            return nil
        }
        if settings.authorization == .jwt && (settings.jwtKeyId.isEmpty || settings.jwtSecretKeyHex.isEmpty) {
            return nil
        }
        return InboxUser(externalUserId: externalUserId, authorization: settings.authorization, applicationCode: settings.applicationCode,
                         jwtKeyId: settings.jwtKeyId, jwtSecretKeyHex: settings.jwtSecretKeyHex)
    }

    /// Settings can be saved only with an Application Code.
    func save(_ settings: ExampleSettings) {
        var settings = settings
        settings.applicationCode = settings.applicationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.baseUrl = settings.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !settings.applicationCode.isEmpty else {
            return
        }
        let applicationChanged = settings.applicationCode != self.settings.applicationCode || settings.baseUrl != self.settings.baseUrl
        self.settings = settings
        settings.save()
        if !isSdkStarted {
            startSDK()
        } else if applicationChanged {
            // The SDK is started once per app launch, like in a real app. Starting it again with another Application Code
            // in the same process would keep the inbox service of the previous application.
            requiresRelaunch = true
        }
    }

    /// Called once per app launch, from the app delegate or for the first saved settings.
    func startSDK() {
        guard !isSdkStarted, !settings.applicationCode.isEmpty else {
            return
        }
        let sdk = settings.baseUrl.isEmpty
            ? MobileMessaging.withApplicationCode(settings.applicationCode, notificationType: [.alert, .sound])
            : MobileMessaging.withApplicationCode(settings.applicationCode, notificationType: [.alert, .sound], backendBaseURL: settings.baseUrl)
        sdk?.start {
            DispatchQueue.main.async {
                self.isSdkStarted = true
                self.refreshStatus()
            }
        }
    }

    func refreshStatus() {
        pushRegistrationId = MobileMessaging.getInstallation()?.pushRegistrationId
        externalUserId = MobileMessaging.getUser()?.externalUserId.flatMap { $0.isEmpty ? nil : $0 }
    }

    func personalize(externalUserId: String) async throws {
        guard let identity = MMUserIdentity(phones: nil, emails: nil, externalUserId: externalUserId) else {
            return
        }
        try await MobileMessaging.personalize(forceDepersonalize: true, userIdentity: identity, userAttributes: nil)
        refreshStatus()
    }

    func depersonalize() async throws {
        _ = try await MobileMessaging.depersonalize()
        refreshStatus()
    }
}
