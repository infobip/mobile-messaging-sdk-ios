//
//  ChatAttachmentPicker.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 19.06.2020.
//

import Foundation
import UIKit
import MobileCoreServices
import Photos

protocol ChatAttachmentPickerDelegate: AnyObject {
    func didSelect(attachment: ChatMobileAttachment)
    func permissionNotGranted(permissionKeys: [String]?)
    func validateAttachmentSize(size: Int) -> Bool
    func attachmentSizeExceeded()
}

class ChatAttachmentPicker: NSObject, NamedLogger {
    
    let infoPlistKeys = [UIImagePickerController.SourceType.camera: ["NSCameraUsageDescription", "NSMicrophoneUsageDescription"],
                         UIImagePickerController.SourceType.photoLibrary: ["NSPhotoLibraryUsageDescription"]]
    
    private let imagePickerController: UIImagePickerController
    private let documentPickerController: UIDocumentPickerViewController
    private weak var delegate: ChatAttachmentPickerDelegate?
    
    init(delegate: ChatAttachmentPickerDelegate) {
        self.imagePickerController = UIImagePickerController()
        if #available(iOS 14.0, *) {
            self.documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: [.directory, .item ])
        } else {
            self.documentPickerController = UIDocumentPickerViewController(documentTypes: [kUTTypeContent as String], in: .open)
        }
        super.init()
        self.imagePickerController.delegate = self
        self.documentPickerController.delegate = self
        self.documentPickerController.allowsMultipleSelection = false
        self.delegate = delegate
    }
    
    private func action(for type: UIImagePickerController.SourceType, title: String, presentationController: UIViewController) -> UIAlertAction? {
        guard UIImagePickerController.isSourceTypeAvailable(type),
            let mediaTypes = UIImagePickerController.availableMediaTypes(for: type) else {
                return nil
        }
        
        if let infoPlistKeys = infoPlistKeys[type] {
            for key in infoPlistKeys {
                guard ChatAttachmentUtils.isInfoPlistKeyDefined(key) else {
                    return nil
                }
            }
        }
        
        self.imagePickerController.mediaTypes = mediaTypes
        
        return UIAlertAction(title: title, style: .default) { [weak self, weak presentationController] _ in
            guard let self = self else { return }
            guard self.checkPermissionsGranted(forSourceType: type) ||
                !self.checkPermissionsDetermined(forSourceType: type) else {
                    self.delegate?.permissionNotGranted(permissionKeys: self.infoPlistKeys[type])
                    return
            }
            self.imagePickerController.sourceType = type
            if type == .camera {
                self.imagePickerController.modalPresentationStyle = .overFullScreen
            }
            
            presentationController?.present(self.imagePickerController, animated: true)
        }
    }
    
    private func browseAction(title: String, presentationController: UIViewController) -> UIAlertAction? {
        if #available(iOS 14.0, *) {
            // On iOS 14 and above, local and iCloud documents are accessed through Files app without restrictions
        } else if FileManager.default.ubiquityIdentityToken == nil {
            // On older versions, iCloud capabilities need to be checked to avoid problems with the documents picker
            logDebug("[InAppChat] iCloud documents unavailable, unable to attach documents")
            return nil
        }
        return UIAlertAction(title: title, style: .default) { [weak self, weak presentationController] _ in
            guard let self = self else { return }
            presentationController?.present(self.documentPickerController, animated: true)
        }
    }

    func present(presentationController: UIViewController, sourceView: UIView? = nil) {
        let alertController = UIAlertController.mmInit(
            title: nil, 
            message: nil,
            preferredStyle: .actionSheet,
            sourceView: sourceView ?? presentationController.view)
        alertController.view.tintColor = MMChatSettings.getMainTextColor()
        if let action = self.action(for: .camera,
                                    title: ChatLocalization.localizedString(forKey: "mm_action_sheet_take_photo_or_video", defaultString: "Take Photo or Video"),
                                    presentationController: presentationController) {
            alertController.addAction(action)
        }
        if let action = self.action(for: .photoLibrary,
                                    title: ChatLocalization.localizedString(forKey: "mm_action_sheet_photo_library", defaultString: "Photo Library"),
                                    presentationController: presentationController) {
            alertController.addAction(action)
        }
        if let action = self.browseAction(title: ChatLocalization.localizedString(forKey: "mm_action_sheet_browse", defaultString: "Browse"), presentationController: presentationController) {
            alertController.addAction(action)
        }
        alertController.addAction(UIAlertAction(title: MMLocalization.localizedString(forKey: "mm_button_cancel", defaultString: "Cancel"), style: .cancel, handler: nil))
        
        presentationController.present(alertController, animated: true)
    }
    
    private func pickerController(_ controller: UIViewController, didSelectURL url: URL?) {
        controller.dismiss(animated: true, completion: nil)
        guard let url = url else {
            return
        }
        
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let data = try? Data.init(contentsOf: url) else {
            logError("can't get data from contentsOf url: \(url)")
            return
        }
        didSelect(url.lastPathComponent, data: data)
    }
    
    private func pickerController(_ controller: UIViewController, didSelectImage image: UIImage?) {
        controller.dismiss(animated: true, completion: nil)
        guard let image = image,
            let data = image.jpegData(compressionQuality: 1) else {
                logError("can't convert UIImage to jpegData")
                return
        }
        didSelect(data: data)
    }
    
    private func didSelect(_ fileName: String? = nil, data: Data) {
        guard let sizeIsValid = delegate?.validateAttachmentSize(size: data.count), sizeIsValid else {
            delegate?.attachmentSizeExceeded()
            return
        }
        delegate?.didSelect(attachment: ChatMobileAttachment(fileName, data: data))
    }
    
    /*Permissions*/
    private func checkPermissionsGranted(forSourceType sourceType: UIImagePickerController.SourceType) -> Bool {
        switch sourceType {
        case .camera:
            return AVCaptureDevice.authorizationStatus(for: .video) == .authorized &&
                   AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .photoLibrary:
            return PHPhotoLibrary.authorizationStatus() == .authorized
        default:
            return true
        }
    }
    
    private func checkPermissionsDetermined(forSourceType sourceType: UIImagePickerController.SourceType) -> Bool {
        switch sourceType {
        case .camera:
            return AVCaptureDevice.authorizationStatus(for: .video) != .notDetermined &&
                   AVCaptureDevice.authorizationStatus(for: .audio) != .notDetermined
        case .photoLibrary:
            return PHPhotoLibrary.authorizationStatus() != .notDetermined
        default:
            return true
        }
    }
}

extension ChatAttachmentPicker: UIImagePickerControllerDelegate {

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                                      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let url = info[.mediaURL] as? URL {
            pickerController(picker, didSelectURL: url)
        } else {
            pickerController(picker, didSelectImage: info[.originalImage] as? UIImage)
        }
    }
}

extension ChatAttachmentPicker: UINavigationControllerDelegate {}

extension ChatAttachmentPicker: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        pickerController(controller, didSelectURL: url)
    }
}

public extension UIAlertController {
    static func mmInit(
        title: String?,
        message: String?,
        preferredStyle: UIAlertController.Style,
        sourceView: UIView) -> UIAlertController {
        let alertController = UIAlertController.init(title: title, message: message, preferredStyle: preferredStyle)
        if UIDevice.current.userInterfaceIdiom == .pad,
            let popoverController = alertController.popoverPresentationController {
            popoverController.backgroundColor = MMChatSettings.sharedInstance.backgroundColor
            popoverController.sourceView = sourceView
            popoverController.sourceRect = sourceView.frame
            popoverController.permittedArrowDirections = []
        }
        return alertController
    }
}
