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


                Button("Send Message") {
                    let text = "Some text \(Int.random(in: 0..<1000))"
                    api?.sendText(text, completion: { error in
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
                    
                    api?.sendAttachment("icon-user-border.png", data: data, completion:  { error in
                        if let error = error {
                            self.performedActions.append(.init(name: "Error: Send image", description: error.localizedDescription))
                        } else {
                            self.performedActions.append(.init(name: "Send image", description: "Image sent"))
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
        }
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
            
            List(threads ?? [], id: \.self) { item in
                HStack {
                    Text(item)
                    
                    Spacer()
                    
                    Button("Select") {
                        api?.openThread(with: item, completion: { result in
                            switch result {
                            case .success(let conv):
                                self.curr = conv.id
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

            Button("Get threads") {
                api?.getThreads(completion: { result in
                    switch result {
                    case .success(let threads):
                        self.threads = threads.map { $0.id }
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
