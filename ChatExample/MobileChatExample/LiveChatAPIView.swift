//
//  LiveChatAPIView.swift
//  MobileChatExample
//
//  Created by Maksym Svitlovskyi on 11/03/2025.
//  Copyright © 2025 Infobip d.o.o. All rights reserved.
//

import SwiftUI
import MobileMessaging

struct PerformedActions: Identifiable, Hashable {
    var id: UUID = .init()
    var name: String
    var description: String
}

struct LiveChatAPIView: View {
    
    @State var api = MobileMessaging.inAppChat?.api
    @State var performedActions: [PerformedActions] = []
    
    var body: some View {
        VStack {
            List(performedActions, id: \.self) { action in
                HStack {
                    Text(action.name)
                    Text(action.description)
                }
            }
            
            Button("Send Message") {
                let text = "Some text \(Int.random(in: 0..<1000))"
                api?.sendText(text, completion: { error in
                    if let error = error {
                        self.performedActions.append(.init(name: "Error: Send message", description: text))
                    } else {
                        self.performedActions.append(.init(name: "Send message", description: text))
                    }
                })
            }
            
            Button("Send contextual") {
                let text = "{ demoKey: \(Int.random(in: 0..<1000)) }"
                api?.sendContextualData(text, multiThreadStrategy: .ACTIVE, completion: { error in
                    if let error = error {
                        self.performedActions.append(.init(name: "Error: Send contextual", description: text + error.localizedDescription))
                    } else {
                        self.performedActions.append(.init(name: "Send contextual", description: text))
                    }
                })
            }
            
            Button("Send attachment") {
                guard let data = UIImage(named: "icon-user-border")?.pngData() else {
                    return
                }
                
                api?.sendAttachment("icon-user-border.png", data: data, completion:  { error in
                    if let error = error {
                        self.performedActions.append(.init(name: "Error: Send image", description: error.localizedDescription))
                    } else {
                        self.performedActions.append(.init(name: "Send image", description: "Image sent"))
                    }
                })
            }
            
            Button("Reset") {
                api?.reset()
            }
            
            Button("Load") {
                api?.loadWidget()
            }
        }
    }
}
