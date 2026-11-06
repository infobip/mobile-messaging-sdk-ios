//
//  InboxExample/InboxExample/Views/SettingsView.swift
//  InboxExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import SwiftUI

/// Application Code, authorization, topics and the inbox user, so the example runs without editing code.
struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var draft = AppModel.shared.settings
    @State private var externalUserId = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Application Code", text: $draft.applicationCode)
                TextField("Base URL (optional)", text: $draft.baseUrl)
                    .keyboardType(.URL)
            } header: {
                Text("Application")
            } footer: {
                Text("From the App Profile. Set a base URL only if Infobip gave you one.")
            }

            Section {
                Picker("Authorization", selection: $draft.authorization) {
                    Text("App code").tag(ExampleSettings.Authorization.applicationCode)
                    Text("JWT").tag(ExampleSettings.Authorization.jwt)
                }
                .pickerStyle(.segmented)
                if draft.authorization == .jwt {
                    TextField("JWT key ID", text: $draft.jwtKeyId)
                    SecureField("Secret key (hex)", text: $draft.jwtSecretKeyHex)
                }
            } header: {
                Text("Inbox authorization")
            } footer: {
                Text(draft.authorization == .jwt
                     ? "Signs the JWT on the device with a key from \"JWT private keys for mobile app inbox\". The secret stays in memory. For testing only: in your app the JWT comes from your backend."
                     : "Sandbox applications only. Must match the Inbox authorization type on the App Profile.")
            }

            Section {
                TextField("Topics, comma separated", text: $draft.topics)
            } header: {
                Text("Topics")
            } footer: {
                Text("Offered as filters on the inbox screen.")
            }

            Section {
                Button("Save") {
                    app.save(draft)
                    draft = app.settings
                }
                .disabled(draft == app.settings || draft.applicationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section {
                if let current = app.externalUserId {
                    // Depersonalize first to switch to another user.
                    status("External User ID", current)
                    Button("Depersonalize", role: .destructive) { run { try await app.depersonalize() } }
                        .disabled(isBusy || !canPersonalize)
                } else {
                    TextField("External User ID", text: $externalUserId)
                    Button("Personalize") { run { try await app.personalize(externalUserId: externalUserId.trimmingCharacters(in: .whitespaces)) } }
                        .disabled(isBusy || !canPersonalize || externalUserId.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("User")
            } footer: {
                Text("Messages are stored in the inbox only for users with an External User ID.")
            }

            if app.requiresRelaunch {
                Section {
                    Text("Relaunch the app to use the new Application Code or base URL.")
                        .foregroundColor(.orange)
                }
            }

            Section("Status") {
                status("SDK", app.isSdkStarted ? "Started" : "Not started")
                status("Push registration", app.pushRegistrationId ?? "Pending")
            }
        }
        .navigationTitle("Settings")
        .disableAutocorrection(true)
        .textInputAutocapitalization(.never)
        .onAppear { app.refreshStatus() }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canPersonalize: Bool {
        return app.isSdkStarted && app.pushRegistrationId != nil
    }

    private func status(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.caption).foregroundColor(.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        isBusy = true
        Task {
            do {
                try await action()
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }
}
