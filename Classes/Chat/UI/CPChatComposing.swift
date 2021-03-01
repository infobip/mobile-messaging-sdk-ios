//
//  CPChatComposing.swift
//
//  Created by Andrey Kadochnikov on 10.09.15.
//
import Foundation

//MARK: Compose bar
class CPComposeBarDelegate: NSObject, ComposeBarDelegate {
	weak var scrollView: UIScrollView?
	let sendTextBlock: (String) -> Void
    let utilityButtonClickedBlock: () -> Void
    let textViewDidChangedBlock: (String) -> Void
    
    let userInputDebounceTimeMs = 250.0
    
    lazy var draftPostponer = MMPostponer(executionQueue: DispatchQueue.main)
	
	init(scrollView: UIScrollView,
         sendTextBlock: @escaping(String) -> Void,
         utilityButtonClickedBlock: @escaping () -> Void,
         textViewDidChangedBlock: @escaping (String) -> Void) {
		self.scrollView = scrollView
		self.sendTextBlock = sendTextBlock
        self.utilityButtonClickedBlock = utilityButtonClickedBlock
        self.textViewDidChangedBlock = textViewDidChangedBlock
	}
	
	public func composeBarDidPressButton(composeBar: ComposeBar) {
		sendTextBlock(composeBar.text)
		composeBar.text = ""
	}
	
	public func composeBarDidPressUtilityButton(composeBar: ComposeBar) {
		_ = composeBar.resignFirstResponder()
        utilityButtonClickedBlock()
	}
	
	func composeBar(composeBar: ComposeBar, willChangeFromFrame startFrame: CGRect, toFrame endFrame: CGRect, duration: TimeInterval, animationCurve: UIView.AnimationCurve) {
		let heightDelta = startFrame.height - endFrame.height
		
		self.scrollView?.contentInset.top -= heightDelta
		self.scrollView?.frame.y += heightDelta
	}
	
	func composeBarTextViewDidBeginEditing(composeBar: ComposeBar) {}
	func composeBarTextViewDidChange(composeBar: ComposeBar) {
        draftPostponer.postponeBlock(delay: userInputDebounceTimeMs) { [weak self] in
            self?.textViewDidChangedBlock(composeBar.text)
        }
    }
	func composeBar(composeBar: ComposeBar, didChangeFromFrame startFrame: CGRect, toFrame endFrame: CGRect) {}
}

