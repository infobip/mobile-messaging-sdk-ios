//
//  ChatExample/MobileChatExample/SwiftUIChatView.swift
//  MobileChatExample
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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

// MARK: - Default Chat (simplest usage)

struct DefaultChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var chatCoordinator: MMChatView.Coordinator?

    var body: some View {
        MMChatView()
            .onMakeChatCoordinator { chatCoordinator = $0 }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if chatCoordinator?.handleBackAction() ?? true {
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "chevron.backward")
                            Text("Back")
                        }
                    }
                }
            }
    }
}

// MARK: - Chat with Custom Navigation

struct ExternalInputChatViewWithCustomNavigation: View {
    @Environment(\.dismiss) private var dismiss
    @State private var chatCoordinator: MMChatView.Coordinator?

    var body: some View {
        NavigationView {
            NavigationLink(destination: chatView()) {
                Text("Open chat using navigation link")
            }
        }
    }

    @ViewBuilder func chatView() -> some View {
        MMChatView()
            .onMakeChatCoordinator { chatCoordinator = $0 }
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button(
                    action: {
                        if chatCoordinator?.handleBackAction() ?? true {
                            dismiss()
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

// MARK: - Chat with External Input

struct ExternalInputChatView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showImagePicker: Bool = false
    @State private var showAlert: Bool = false
    @State private var errorText: String = ""
    @State private var chatState: MMChatWebViewState? = .unknown
    @State private var chatCoordinator: MMChatView.Coordinator?

    var body: some View {
        VStack {
            MMChatView()
                .useExternalChatInput()
                .onChatStateChange { state in
                    chatState = state
                }
                .onMakeChatCoordinator { chatCoordinator = $0 }
            makeChatInput()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if chatCoordinator?.handleBackAction() ?? true {
                        dismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.backward")
                        Text("Back")
                    }
                }
            }
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
    }

    @ViewBuilder func makeChatInput() -> some View {
        switch chatState {
        case .loading, .threadList, .closedThread, .unknown, .loadingThread: EmptyView()
        default:
            Divider()
            ChatInputView(
                onSendDidTap: { text in
                    Task {
                        do {
                            try await chatCoordinator?.chatVC?.send(text.livechatBasicPayload)
                        } catch {
                            self.errorText = "Error: \(error.localizedDescription)"
                            self.showAlert = true
                        }
                    }
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
            Task {
                do {
                    try await chatCoordinator?.chatVC?.send(payload)
                } catch {
                    self.errorText = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
        return imagePicker
    }
}

// MARK: - Reusable Input Views

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
