//
//  CPChatComposing.swift
//
//  Created by Andrey Kadochnikov on 10.09.15.
//
import Foundation
import UIKit

//MARK: Compose bar
public protocol MMComposeBarDelegate: UITextViewDelegate {
    @available(*, deprecated, message: "Method 'send' needs to be used instead. This method will be removed in a future release")
    func sendText(_ text: String, completion: @escaping (_ error: NSError?) -> Void)
    @available(*, deprecated, message: "Method 'send' needs to be used instead. This method will be removed in a future release")
    func sendAttachment(_ fileName: String?, data: Data, completion: @escaping (_ error: NSError?) -> Void)
    @available(*, deprecated, message: "Method 'send' needs to be used instead. This method will be removed in a future release")
    func sendDraft(_ message: String?, completion: @escaping (_ error: NSError?) -> Void)
    func send(_ payload: MMLivechatPayload, completion: @escaping (_ error: NSError?) -> Void) 
    func textDidChange(_ text: String?, completion: @escaping (_ error: NSError?) -> Void)
    func attachmentButtonTapped()
    func composeBarWillChangeFrom(_ startFrame: CGRect, to endFrame: CGRect,
                                       duration: TimeInterval, animationCurve: UIView.AnimationCurve)
    func composeBarDidChangeFrom(_ startFrame: CGRect, to endFrame: CGRect)
}

public protocol MMChatComposer: UIView {
    var delegate: MMComposeBarDelegate? { set get }
}
