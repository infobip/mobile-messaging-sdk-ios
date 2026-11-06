//
//  InboxExample/InboxExample/Views/InboxView.swift
//  InboxExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import SwiftUI
import MobileMessaging

struct InboxView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var inbox: InboxModel
    @State private var topic: String?
    @State private var actionError: String?

    var body: some View {
        content
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !app.settings.topicList.isEmpty {
                        topicMenu
                    }
                }
            }
            .alert("Inbox", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(actionError ?? "")
            }
            // A topic removed in Settings can no longer be selected, so show all topics again.
            .onChange(of: app.settings.topicList) { topics in
                if let selected = topic, !topics.contains(selected) {
                    topic = nil
                }
            }
            .task(id: LoadKey(user: app.inboxUser, topic: topic)) {
                await inbox.load(user: app.inboxUser, topic: topic, pageSize: 20)
            }
            // New messages may have been stored while the app was in the background or when a push message arrives.
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await inbox.refresh() }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name(MMNotificationMessageReceived))) { _ in
                Task { await inbox.refresh() }
            }
    }

    @ViewBuilder
    private var content: some View {
        if app.inboxUser == nil {
            placeholder("Not set up", systemImage: "gearshape", text: "Enter the Application Code and an External User ID in Settings.")
        } else if inbox.messages.isEmpty && !inbox.hasMorePages {
            if !inbox.hasLoaded {
                ProgressView()
            } else if let error = inbox.errorMessage {
                placeholder("Couldn't load the inbox", systemImage: "exclamationmark.triangle", text: error, retry: true)
            } else {
                placeholder("No messages", systemImage: "tray", text: "Send a push message with \"Send to inbox\" to this External User ID.", retry: true)
            }
        } else {
            list
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(inbox.messages) { message in
                    NavigationLink(destination: MessageView(message: message)) {
                        MessageRow(message: message)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            perform { try await inbox.delete([message.id]) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if !message.isSeen {
                            Button {
                                perform { try await inbox.markSeen([message.id]) }
                            } label: {
                                Label("Read", systemImage: "envelope.open")
                            }
                            .tint(.blue)
                        }
                    }
                }
            } header: {
                Text(counters)
            } footer: {
                footer
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await inbox.refresh() }
    }

    @ViewBuilder
    private var footer: some View {
        if let error = inbox.errorMessage {
            Text(error)
                .foregroundColor(.red)
            if !inbox.hasMorePages {
                // The list can't be continued (for example after INVALID_CURSOR): load it again from the first page.
                Button("Refresh") { Task { await inbox.refresh() } }
                    .disabled(inbox.isLoading)
            }
        }
        if inbox.hasMorePages {
            HStack {
                Spacer()
                if inbox.isLoading {
                    ProgressView()
                } else {
                    Button("Load more") { Task { await inbox.loadMore() } }
                }
                Spacer()
            }
            .padding(.vertical, 8)
            // Loads the next page when the end of the list becomes visible.
            .onAppear { Task { await inbox.loadMore() } }
        }
    }

    private var counters: String {
        var text = "\(inbox.countTotal) messages, \(inbox.countUnread) unread"
        if let total = inbox.countTotalFiltered, let unread = inbox.countUnreadFiltered {
            text += " · topic: \(total), \(unread) unread"
        }
        return text
    }

    private var topicMenu: some View {
        Menu {
            Picker("Topic", selection: $topic) {
                Text("All topics").tag(String?.none)
                ForEach(app.settings.topicList, id: \.self) { topic in
                    Text(topic).tag(String?.some(topic))
                }
            }
        } label: {
            Label(topic ?? "All topics", systemImage: topic == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private func placeholder(_ title: String, systemImage: String, text: String, retry: Bool = false) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if retry {
                Button("Refresh") { Task { await inbox.refresh() } }
                    .disabled(inbox.isLoading)
            }
        }
        .padding()
    }

    private func perform(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                actionError = error.inboxMessage
            }
        }
    }

    private struct LoadKey: Equatable {
        let user: InboxUser?
        let topic: String?
    }
}

private struct MessageRow: View {
    let message: InboxMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(message.isSeen ? Color.clear : Color.blue)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.title ?? message.text ?? "(no text)")
                        .fontWeight(message.isSeen ? .regular : .semibold)
                        .lineLimit(1)
                    Spacer()
                    Text(message.sentAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if message.title != nil, let text = message.text {
                    Text(text)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                if let topic = message.topic {
                    Text(topic)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
            }
        }
        .padding(.vertical, 2)
    }
}
