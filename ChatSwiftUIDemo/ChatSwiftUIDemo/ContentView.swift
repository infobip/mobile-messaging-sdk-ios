// 
//  ChatSwiftUIDemo/ChatSwiftUIDemo/ContentView.swift
//  ChatSwiftUIDemo
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import SwiftUI
import InAppChat
import WebRTCUI
import InfobipRTC

final class ChatBackBridge: ObservableObject {
    var onBackTapped: (() -> Bool)?
}

struct CustomBackButton: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var backBridge: ChatBackBridge

    var body: some View {
        Button {
            // We check if chat has internal navigation that needs to go back first:
            // onBackTapped returns true if we should dismiss, false if handled internally
            if backBridge.onBackTapped?() ?? true {
                // No internal navigation, dismiss to home screen
                dismiss()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.backward")
            }
        }
    }
}

struct ContentView: SwiftUI.View {
    @StateObject private var backBridge = ChatBackBridge()

    var body: some SwiftUI.View {
        NavigationStack {
            ZStack {
                NavigationLink(destination: chatViewWithCustomBack()) {
                    Text("Show chat")
                }
            }
            .padding()
        }.navigationViewStyle(StackNavigationViewStyle())
    }
    
    @ViewBuilder
    private func chatViewWithCustomBack() -> some View {
        ChatView(backBridge: backBridge)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    CustomBackButton(backBridge: backBridge)
                }
            }
    }
}

#Preview {
    ContentView()
}

struct ChatView: UIViewControllerRepresentable {
    @ObservedObject var backBridge: ChatBackBridge

    func makeUIViewController(context: Context) -> InAppChat.MMChatViewController {
        MobileMessaging.webRTCService?.delegate = context.coordinator
        MMChatSettings.sharedInstance.shouldSetNavBarAppearance = false
        MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance = false
        backBridge.onBackTapped = { [weak coordinator = context.coordinator] in
           return coordinator?.handleBackAction() ?? false
        }
        return context.coordinator.chatVC
    }
    
    func updateUIViewController(_ uiViewController: InAppChat.MMChatViewController, context: Context) {
        backBridge.onBackTapped = { [weak coordinator = context.coordinator] in
           return coordinator?.handleBackAction() ?? false
        }
    }
    
    typealias UIViewControllerType = MMChatViewController
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    class Coordinator: MMWebRTCDelegate {
        let chatVC = MMChatViewController.makeChildNavigationViewController()

        func handleBackAction() -> Bool {
            // Use SDK's method to check if back should dismiss or be handled internally
            return chatVC.onCustomBackPressed()
        }
        
        func inboundCallEstablished(_ call: ApplicationCall, event: CallEstablishedEvent) {
            if let callController = MobileMessaging.webRTCService?.getInboundCallController(
                incoming: call,
                establishedEvent: event
            ) {
                chatVC.present(callController, animated: true)
            }
        }
        
        func inboundWebRTCCallEstablished(_ call: WebrtcCall, event: CallEstablishedEvent) {
            if let callController = MobileMessaging.webRTCService?.getInboundCallController(
                incoming: call,
                establishedEvent: event
            ) {
                chatVC.present(callController, animated: true)
            }
        }
        
        func callRegistrationEnded(with statusCode: MMWebRTCRegistrationCode, and error: Error?) {
            print("Registration ended")
        }
        
        func callUnregistrationEnded(with statusCode: MMWebRTCRegistrationCode, and error: Error?) {
            print("Unregistration ended")
        }
    }
}
