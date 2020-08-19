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

protocol ChatAttachmentPickerDelegate: class {
    func didSelect(attachment: ChatAttachment)
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
        self.documentPickerController = UIDocumentPickerViewController(documentTypes: [kUTTypeContent as String], in: .open)
        super.init()
        self.imagePickerController.delegate = self
        self.documentPickerController.delegate = self
        self.delegate = delegate
    }

    private func action(for type: UIImagePickerController.SourceType, title: String, presentationController: UIViewController) -> UIAlertAction? {
        guard UIImagePickerController.isSourceTypeAvailable(type),
              let mediaTypes = UIImagePickerController.availableMediaTypes(for: type) else {
            return nil
        }
        
        if let infoPlistKeys = infoPlistKeys[type] {
            for key in infoPlistKeys {
                guard let _ = Bundle.main.infoDictionary?.index(forKey: key) else {
                    logWarn("\(key) isn't defined in info.plist")
                    return nil
                }
            }
        }

        self.imagePickerController.mediaTypes = mediaTypes

        return UIAlertAction(title: title, style: .default) { [unowned self, unowned presentationController] _ in
            guard self.checkPermissionsGranted(forSourceType: type) ||
                  !self.checkPermissionsDetermined(forSourceType: type) else {
                self.delegate?.permissionNotGranted(permissionKeys: self.infoPlistKeys[type])
                return
            }
            self.imagePickerController.sourceType = type
            presentationController.present(self.imagePickerController, animated: true)
        }
    }
    
    private func browseAction(title: String, presentationController: UIViewController) -> UIAlertAction? {
        return UIAlertAction(title: title, style: .default) { [unowned self, unowned presentationController] _ in
            presentationController.present(self.documentPickerController, animated: true)
        }
    }

   func present(presentationController: UIViewController) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

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
        didSelect(data: data)
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
    
    private func didSelect(data: Data) {
        guard let sizeIsValid = delegate?.validateAttachmentSize(size: data.count), sizeIsValid else {
            delegate?.attachmentSizeExceeded()
            return
        }
        delegate?.didSelect(attachment: ChatAttachment(data: data))
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
