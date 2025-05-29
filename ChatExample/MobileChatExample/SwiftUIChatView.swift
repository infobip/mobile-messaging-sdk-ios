//
//  CustomChatView.swift
//  MobileChatExample
//
//  Created by Maksym Svitlovskyi on 27/09/2023.
//  Copyright © 2023 Infobip d.o.o. All rights reserved.
//

import SwiftUI
import MobileMessaging
import PhotosUI
#if USING_SPM
import WebRTCUI
import InAppChat
import MobileMessagingLogging
#endif
typealias View = SwiftUI.View

struct ExternalInputChatViewWithCustomNavigation: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            NavigationLink(destination: getChatView(), label: {
                Text("Open chat using navigation link")
            })
        }
    }
    
    @ViewBuilder func getChatView() -> some View {
        let chatView = ChatViewRepresentable(shouldUseCustomChatInput: false, chatState: .constant(nil))
        chatView
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button(
                    action: {
                        if chatView.chatController.onCustomBackPressed() {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }, label: {
                        HStack {
                            Image(systemName: "chevron.backward")
                            Text("Back")
                        }
                    })
            )
    }
}

struct DefaultChatView: View {
    
    var body: some View {
        VStack {
            ChatViewRepresentable(shouldUseCustomChatInput: false, chatState: .constant(nil))
        }
    }
}

struct ExternalInputChatView: View {

    @State private var showImagePicker: Bool = false
    
    @State private var showAlert: Bool = false
    @State private var errorText: String = ""
    
    @State private var chatState: MMChatWebViewState? = .unknown
    @State private var chatController: MMChatViewController?
    
    var body: some View {
        VStack {
            makeChat()
            makeChatInput()
        }
        .sheet(isPresented: $showImagePicker, content: {
            prepareImagePicker()
        })
        .alert(isPresented: $showAlert, content: {
            Alert(
                title: Text("Error"),
                message: Text(errorText),
                dismissButton: .default(Text("OK"))
            )
        })
        .padding(.top)
    }
    
    @ViewBuilder func makeChat() -> some View {
        let chatView = ChatViewRepresentable(shouldUseCustomChatInput: true, chatState: $chatState)
        chatView
            .onAppear {
                self.chatController = chatView.chatController
            }
    }
    
    @ViewBuilder func makeChatInput() -> some View {
        switch chatState {
        case .loading, .threadList, .closedThread, .unknown, .loadingThread: EmptyView()
        default:
            Divider()
            ChatInputView(
                onSendDidTap: { text in
                    chatController?.send(text.livechatBasicPayload, completion:  { error in
                        if let error = error {
                            self.errorText = "Error: \(error.localizedDescription)"
                            self.showAlert = true
                        }
                    })
                },
                onAttachmentDidTap: {
                    showImagePicker.toggle()
                }
            )
        }
    }
    
    func prepareImagePicker() -> ImagePickerRepresentable {
        var imagePicker = ImagePickerRepresentable(isPresenting: $showImagePicker)
        imagePicker.didFinishPickingWithImage = { image in
            guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
            let payload = MMLivechatBasicPayload(data: imageData)
            chatController?.send(payload, completion:  { error in
                if let error = error {
                    self.errorText = "Error: \(String(describing: error.localizedDescription))"
                    self.showAlert = true
                }
            })
        }
        return imagePicker
    }
}

struct ChatViewRepresentable: UIViewControllerRepresentable {
    typealias UIViewControllerType = MMChatViewController
    
    let chatController = MMChatViewController()
    private let shouldUseCustomChatInput: Bool
    
    @Binding var chatState: MMChatWebViewState?
    
    init(shouldUseCustomChatInput: Bool, chatState: Binding<MMChatWebViewState?>) {
        self.shouldUseCustomChatInput = shouldUseCustomChatInput
        self._chatState = chatState
    }
    
    func makeUIViewController(context: Context) -> MMChatViewController {
        MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance = false
        MMChatSettings.sharedInstance.shouldUseExternalChatInput = shouldUseCustomChatInput
        return chatController
    }
    
    func updateUIViewController(_ uiViewController: MMChatViewController, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MMInAppChatDelegate {
        let parent: ChatViewRepresentable
        init(_ parent: ChatViewRepresentable) {
            self.parent = parent
            super.init()
            if parent.chatState != nil {
                MobileMessaging.inAppChat?.delegate = self
            }
        }
        
        func chatDidChange(to state: MMChatWebViewState) {
            parent.chatState = state
        }
    }
}

struct ChatInputView: View {
    @State var text: String = ""
    
    var onSendDidTap: (String) -> Void
    var onAttachmentDidTap: () -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                onAttachmentDidTap()
            }, label: {
                Image(systemName: "paperclip.circle")
                    .imageScale(.large)
            })
            
            TextField("Message", text: $text)
                .padding(.horizontal, 2.5).padding(.trailing, 5).padding(.leading, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .inset(by: 3)
                        .stroke(.gray, lineWidth: 1)
                        .padding(.vertical, -5)
                        .padding(.leading, -5)
                )

            Button(action: {
                onSendDidTap(text)
                text = ""
            }, label: {
                Image(systemName: "paperplane")
                    .imageScale(.large)
            })
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
    }
}

struct ImagePickerRepresentable: UIViewControllerRepresentable {
    var didFinishPickingWithImage: ((UIImage) -> Void)?
    @Binding var isPresenting: Bool
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerRepresentable
        init(_ parent: ImagePickerRepresentable) {
            self.parent = parent
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.didFinishPickingWithImage?(uiImage)
                parent.isPresenting = false
            }
        }
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
}
