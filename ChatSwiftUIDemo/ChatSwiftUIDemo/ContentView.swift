//
//  ChatSwiftUIDemo/ChatSwiftUIDemo/ContentView.swift
//  ChatSwiftUIDemo
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import SwiftUI
import InAppChat
import WebRTCUI
import InfobipRTC

struct ContentView: SwiftUI.View {

    var body: some SwiftUI.View {
        NavigationStack {
            VStack(spacing: 20) {
                NavigationLink("Show chat (simple)") {
                    SimpleChatScreen()
                }
                NavigationLink("Show chat (all features)") {
                    FeatureShowcaseChatScreen()
                }
            }
            .padding()
        }
    }
}

// MARK: - Simple Chat

/// Simplest possible integration using MMChatView.
/// The back button delegates to the chat coordinator for multithread navigation handling.
struct SimpleChatScreen: SwiftUI.View {
    @Environment(\.dismiss) private var dismiss
    @State private var chatCoordinator: MMChatView.Coordinator?

    var body: some SwiftUI.View {
        MMChatView()
            .onMakeChatCoordinator { coordinator in
                chatCoordinator = coordinator
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if chatCoordinator?.handleBackAction() ?? true {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                }
            }
    }
}

// MARK: - Feature Showcase

/// Demonstrates all available MMChatView modifiers.
struct FeatureShowcaseChatScreen: SwiftUI.View {
    @Environment(\.dismiss) private var dismiss
    @State private var chatCoordinator: MMChatView.Coordinator?
    @State private var chatState: MMChatWebViewState = .unknown
    @State private var isChatEnabled: Bool = true
    @State private var unreadCount: Int = 0
    @State private var exceptionMessage: String?
    @State private var showExceptionAlert: Bool = false

    var body: some SwiftUI.View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(isChatEnabled ? .green : .red)
                    .frame(width: 8, height: 8)
                Text("State: \(String(describing: chatState))")
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemBackground))

            MMChatView()
                .onMakeChatCoordinator { chatCoordinator = $0 }
                .onChatStateChange { state in
                    chatState = state
                }
                .onChatEnabled { enabled in
                    isChatEnabled = enabled
                }
                .onUnreadMessagesCountChange { count in
                    unreadCount = count
                }
                .onChatException { exception in
                    exceptionMessage = exception.message ?? "Unknown error (code: \(exception.code))"
                    showExceptionAlert = true
                    return .noDisplay
                }
                //.widgetTheme("default") // Note: Unnecessary in practice as "default" widget is used by default
                //.language(.en) // Note: Unnecessary in practice as English is the default language
                // Uncomment and provide a real token if your widget requires JWT authentication:
                // .jwtProvider { return "your-jwt-token" }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if chatCoordinator?.handleBackAction() ?? true {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.backward")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption2).bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.red))
                }
            }
        }
        .alert("Chat Exception", isPresented: $showExceptionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exceptionMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
}
