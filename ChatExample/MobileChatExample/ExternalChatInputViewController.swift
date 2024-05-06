//
//  ExternalChatInputViewController.swift
//  MobileChatExample
//
//  Created by Maksym Svitlovskyi on 28/09/2023.
//  Copyright © 2023 Infobip d.o.o. All rights reserved.
//

import UIKit
import MobileMessaging
#if USING_SPM
import WebRTCUI
import InAppChat
import MobileMessagingLogging
#endif

class ExternalChatInputViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    lazy var chatView: MMChatViewController = {
        let chatViewController = MMChatViewController()
        chatViewController.view.translatesAutoresizingMaskIntoConstraints = false
        MMChatSettings.sharedInstance.shouldUseExternalChatInput = true
        return chatViewController
    }()
    
    lazy var externalChatInput: ExternalChatInputView = {
        let chatInput = ExternalChatInputView()
        chatInput.translatesAutoresizingMaskIntoConstraints = false
        return chatInput
    }()
    
    lazy var picker: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.delegate = self
        return picker
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(externalChatInput)
        
        self.externalChatInput.isHidden = true
        MobileMessaging.inAppChat?.delegate = self

        
        addChild(chatView)
        view.addSubview(chatView.view)
        chatView.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            chatView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatView.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 20)
        ])
        
        NSLayoutConstraint.activate([
            externalChatInput.topAnchor.constraint(equalTo: chatView.view.bottomAnchor),
            externalChatInput.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            externalChatInput.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            externalChatInput.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        externalChatInput.sendButton.addTarget(self, action: #selector(sendText), for: .touchDown)
        externalChatInput.attachmentButton.addTarget(self, action: #selector(presentImagePicker), for: .touchDown)
    }
    
    @objc func sendText() {
        if let text = externalChatInput.textField.text {
            externalChatInput.textField.text = ""
            chatView.sendText(text, completion: { error in
                
            })
        }
    }
    
    @objc func presentImagePicker() {
        self.present(picker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
            self.chatView.sendAttachment(data: imageData, completion: { error in
                if let error = error {
                    print(error)
                }
            })
            picker.dismiss(animated: true)
        }
    }
}

extension ExternalChatInputViewController: MMInAppChatDelegate {
    func chatDidChange(to state: MMChatWebViewState) {
        switch state {
        case .loading, .threadList, .closedThread, .unknown, .loadingThread:
            self.externalChatInput.isHidden = true
            self.externalChatInput.resignFirstResponder()
        default:
            self.externalChatInput.isHidden = false
        }
    }
}

class ExternalChatInputView: UIView {
    
    var sendButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "paperplane"), for: .normal)
        return button
    }()
    
    var textField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Message..."
        return textField
    }()
    
    var attachmentButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "paperclip.circle"), for: .normal)
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .white
        
        let stackView = UIStackView(arrangedSubviews: [
            attachmentButton, textField, sendButton
        ])
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
