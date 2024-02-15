//
//  ContentView.swift
//  ChatSwiftUIDemo
//
//  Created by Maksym Svitlovskyi on 14/02/2024.
//  Copyright © 2023 Infobip Ltd. All rights reserved.
//

import SwiftUI
import InAppChat
import WebRTCUI
import InfobipRTC

struct ContentView: SwiftUI.View {
    @State var showChat: Bool = false

    var showBtn: some SwiftUI.View {
        Button("Show livechat + custom webRTCUI presentation") {
            showChat.toggle()
        }
    }

    var body: some SwiftUI.View {
        NavigationView {
            VStack(spacing: 20) {
                NavigationLink(destination: NavigationLazyView(LiveChatViewControllerRepresentable()), isActive: $showChat, label: {
                    showBtn
                })
            }
            .padding()
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}

struct NavigationLazyView<Content: SwiftUI.View>: SwiftUI.View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

#Preview {
    ContentView()
}

struct LiveChatViewControllerRepresentable: UIViewControllerRepresentable {
    var liveChatVC = MMChatViewController.makeModalViewController()
    func makeUIViewController(context: Context) -> InAppChat.MMChatViewController {
        MobileMessaging.webRTCService?.delegate = context.coordinator
        MMChatSettings.sharedInstance.shouldSetNavBarAppearance = false
        MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance = false
        return liveChatVC
    }
    
    func updateUIViewController(_ uiViewController: InAppChat.MMChatViewController, context: Context) { }
    
    typealias UIViewControllerType = MMChatViewController
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    class Coordinator: MMWebRTCDelegate {
        func inboundCallEstablished(_ call: ApplicationCall, event: CallEstablishedEvent) {
            if let callController = MobileMessaging.webRTCService?.getInboundCallController(
                incoming: call,
                establishedEvent: event
            ) {
                parent.liveChatVC.present(callController, animated: true)
            }
        }
        
        func inboundWebRTCCallEstablished(_ call: WebrtcCall, event: CallEstablishedEvent) {
            if let callController = MobileMessaging.webRTCService?.getInboundCallController(
                incoming: call,
                establishedEvent: event
            ) {
                parent.liveChatVC.present(callController, animated: true)
            }
        }
        
        func callRegistrationEnded(with statusCode: MMWebRTCRegistrationCode, and error: Error?) {
            print("Registration ended")
        }
        
        func callUnregistrationEnded(with statusCode: MMWebRTCRegistrationCode, and error: Error?) {
            print("Unregistration ended")
        }

        private let parent: LiveChatViewControllerRepresentable
        
        init(parent: LiveChatViewControllerRepresentable) {
            self.parent = parent
        }
    }
}

