// 
//  ChatExample/MobileChatExample/LiveChatAPIView.swift
//  MobileChatExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import SwiftUI
import MobileMessaging
import UniformTypeIdentifiers
#if USING_SPM
import InAppChat
import MobileMessagingLogging
#endif

struct PerformedActions: Identifiable, Hashable {
    var id: UUID = .init()
    var name: String
    var description: String
}

struct LiveChatAPIView: View {
    
    @State var api = MobileMessaging.inAppChat?.api
    @State var performedActions: [PerformedActions] = []
    
    var body: some View {
        NavigationView {
            VStack {
                List(performedActions, id: \.self) { action in
                    HStack {
                        Text(action.name)
                        Text(action.description)
                    }
                }
                
                NavigationLink(destination: ThreadAPIView(), label: {
                    Text("Thread API")
                }).frame(height: 40)

                Button("Send Text Message") {
                    let text = "Some text \(Int.random(in: 0..<1000))"
                    api?.send(text.livechatBasicPayload, completion: { error in
                        if let error = error {
                            self.performedActions.append(.init(name: "Error: Send message", description: text + " " + error.localizedDescription))
                        } else {
                            self.performedActions.append(.init(name: "Send message", description: text))
                        }
                    })
                }.frame(height: 40)

                Button("Send Text Message (to threadId from clipboard)") {
                    let text = "Some text \(Int.random(in: 0..<1000))"
                    let payload = MMLivechatBasicPayload(text: text, threadId: UIPasteboard.general.string)
                    api?.send(payload, completion: { error in
                        if let error = error {
                            self.performedActions.append(.init(name: "Error: Send message", description: text + " " + error.localizedDescription))
                        } else {
                            self.performedActions.append(.init(name: "Send message", description: text))
                        }
                    })
                }.frame(height: 40)

                Button("Send contextual") {
                    let text = "{ demoKey: \(Int.random(in: 0..<1000)) }"
                    api?.sendContextualData(text, multiThreadStrategy: .ACTIVE, completion: { error in
                        if let error = error {
                            self.performedActions.append(.init(name: "Error: Send contextual", description: text + " " + error.localizedDescription))
                        } else {
                            self.performedActions.append(.init(name: "Send contextual", description: text))
                        }
                    })
                }.frame(height: 40)

                Button("Send attachment") {
                    guard let data = UIImage(named: "icon-user-border")?.pngData() else {
                        return
                    }

                    let payload = MMLivechatBasicPayload(fileName: "icon-user-border.png", data: data)
                    api?.send(payload, completion:  { error in
                        if let error = error {
                            self.performedActions.append(.init(name: "Error: Send image", description: error.localizedDescription))
                        } else {
                            self.performedActions.append(.init(name: "Send image", description: "Image sent"))
                        }
                    })
                }.frame(height: 40)

                Button("Send Custom Data") {
                    let payload = MMLivechatCustomPayload(
                        customData: "{  \"name\": \"John\",  \"description\": \"This is a custom data file for John.\",  \"version\": \"1.0\",  \"author\": \"Jakub\"}",
                        agentMessage: "Seen only by agent \(Int.random(in: 0..<1000))",
                        userMessage: "Seen by user and agent \(Int.random(in: 0..<1000))")
                    api?.send(payload, completion: { error in
                        if let error = error {
                            self.performedActions.append(.init(name: "Error: Send custom data", description: error.localizedDescription))
                        } else {
                            self.performedActions.append(.init(name: "Send custom data successful", description: "OK"))
                        }
                    })
                }.frame(height: 40)

                Button("Reset") {
                   api?.reset()
                }.frame(height: 40)

                Button("Load") {
                   api?.loadWidget()
                }.frame(height: 40)
            }
        }.background(Color.gray)
    }
}

struct ThreadAPIView: View {
    
    @State var api = MobileMessaging.inAppChat?.api
    
    @State var threads: [String]?

    @State var curr = ""
    
    @State var active = ""
    
    var body: some View {
        VStack {
            
            Text(curr)

            if !(threads?.isEmpty ?? true) {
                Text("(Tap an Id to copy it to your clipboard)")
            }

            List(threads ?? [], id: \.self) { item in
                HStack {
                    Button(item) {
                        if #available(iOS 14.0, *) {
                            UIPasteboard.general.setValue(item, forPasteboardType: UTType.plainText.identifier)
                        }
                    }.frame(height: 40)

                    Spacer()
                    
                    Button("Select") {
                        api?.openThread(with: item, completion: { result in
                            switch result {
                            case .success(let conv):
                                self.curr = conv.id ?? ""
                            case .failure(let error):
                                print(error)
                                return
                            }
                        })
                    }.frame(height: 40)
                }
            }

            if threads != nil {
                Text("No threads for widget")
            }

            Button("Create thread") {
                let text = "Some text \(Int.random(in: 0..<1000))"
                api?.createThread(text.livechatBasicPayload, completion: { (thread, error) in
                    DispatchQueue.mmEnsureMain {
                        self.active = thread?.id ?? "There is no active conv"
                    }
                })
            }.frame(height: 40)

            Button("Get threads") {
                api?.getThreads(completion: { result in
                    switch result {
                    case .success(let threads):
                        self.threads = threads.map { $0.id ?? "" }
                    case .failure(_): return
                    }
                })
            }.frame(height: 40)

            VStack {
                Button("Get Active") {
                    api?.getActiveThread(completion: { result in
                        switch result {
                        case .success(let thread):
                            self.active = thread?.id ?? "There is no active conv"
                        case .failure(_): return
                        }
                    })
                }.frame(height: 40)
                Spacer()
                Text(active)
            }.frame(height: 40)
        }
    }
}
