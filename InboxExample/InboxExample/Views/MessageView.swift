//
//  InboxExample/InboxExample/Views/MessageView.swift
//  InboxExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import SwiftUI

/// Message content and details. Opening an unread message marks it as read.
struct MessageView: View {
    @EnvironmentObject private var inbox: InboxModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var errorMessage: String?
    let message: InboxMessage

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    if let title = message.title {
                        Text(title).font(.title3).bold()
                    }
                    if let text = message.text {
                        Text(text)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Details") {
                field("Sent", message.sentAt.formatted(date: .abbreviated, time: .shortened))
                field("Topic", message.topic ?? "none")
                field("Message ID", message.id)
            }
            if !message.links.isEmpty {
                Section("Links") {
                    ForEach(message.links, id: \.url) { link in
                        Link(link.title, destination: link.url)
                    }
                }
            }
            if !message.customPayload.isEmpty {
                Section("Custom payload") {
                    ForEach(message.customPayload, id: \.key) { field($0.key, $0.value) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Message")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Image(systemName: "trash")
            }
        }
        .confirmationDialog("Delete this message?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await inbox.delete([message.id])
                        dismiss()
                    } catch {
                        errorMessage = error.inboxMessage
                    }
                }
            }
        } message: {
            Text("It is deleted for this user on all devices.")
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            do {
                try await inbox.markSeen([message.id])
            } catch {
                errorMessage = error.inboxMessage
            }
        }
    }

    private func field(_ name: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
