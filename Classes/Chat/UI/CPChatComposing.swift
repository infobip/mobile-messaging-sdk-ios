//
//  CPChatComposing.swift
//
//  Created by Andrey Kadochnikov on 10.09.15.
//
import Foundation
import UIKit

//MARK: Compose bar
public protocol MMComposeBarDelegate: UITextViewDelegate {
    func sendText(_ text: String, completion: @escaping (_ error: NSError?) -> Void)
    func sendAttachment(_ fileName: String?, data: Data, completion: @escaping (_ error: NSError?) -> Void)
    func sendDraft(_ message: String?, completion: @escaping (_ error: NSError?) -> Void)
    func textDidChange(_ text: String?, completion: @escaping (_ error: NSError?) -> Void)
    func attachmentButtonTapped()
    func composeBarWillChangeFrom(_ startFrame: CGRect, to endFrame: CGRect,
                                       duration: TimeInterval, animationCurve: UIView.AnimationCurve)
    func composeBarDidChangeFrom(_ startFrame: CGRect, to endFrame: CGRect)
}

public protocol MMChatComposer: UIView {
    var delegate: MMComposeBarDelegate? { set get }
}
