//
//  CPChatComposing.swift
//
//  Created by Andrey Kadochnikov on 10.09.15.
//
import Foundation

//MARK: Compose bar
class MMComposeBarDelegate: NSObject, ComposeBarDelegate {
	weak var scrollViewContainer: UIView?
	let sendTextBlock: (String) -> Void
    let utilityButtonClickedBlock: () -> Void
    let textViewDidChangedBlock: (String) -> Void
    
    let userInputDebounceTimeMs = 250.0
    
    lazy var draftPostponer = MMPostponer(executionQueue: DispatchQueue.main)
	
	init(scrollViewContainer: UIView,
         sendTextBlock: @escaping(String) -> Void,
         utilityButtonClickedBlock: @escaping () -> Void,
         textViewDidChangedBlock: @escaping (String) -> Void) {
		self.scrollViewContainer = scrollViewContainer
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
        scrollViewContainer?.frame.height += heightDelta;
	}
	
	func composeBarTextViewDidBeginEditing(composeBar: ComposeBar) {}
	func composeBarTextViewDidChange(composeBar: ComposeBar) {
        draftPostponer.postponeBlock(delay: userInputDebounceTimeMs) { [weak self] in
            self?.textViewDidChangedBlock(composeBar.text)
        }
    }
	func composeBar(composeBar: ComposeBar, didChangeFromFrame startFrame: CGRect, toFrame endFrame: CGRect) {}
}

