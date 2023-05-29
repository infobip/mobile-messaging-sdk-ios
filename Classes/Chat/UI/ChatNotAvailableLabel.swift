//
//  ChatNoConnectionLabel.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 11.06.2020.
//

import Foundation
import UIKit

class ChatNotAvailableLabel: UILabel {
    static var kMinHeight: CGFloat = 40.0
    static var kAnimationDuration: TimeInterval = 0.5
    static var kMaxNumberOfLines: Int = 5

    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeLabel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeLabel()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        initializeLabel()
    }
    
    func initializeLabel() {
        textAlignment = .center
        autoresizingMask = [.flexibleWidth]
    }
    
    private func resizeAndReposition(_ changingToVisible: Bool) {
        if changingToVisible {
            let originalWidth = self.frame.size.width
            self.sizeToFit()
            self.frame.size.height = max(self.frame.size.height, ChatNotAvailableLabel.kMinHeight)
            self.frame.size.width = originalWidth
            self.frame.origin.y = -self.frame.height
        } else {
            self.frame.origin.y = 0
        }
    }
    
    func setVisibility(_ changeToVisible: Bool, text: String?) {
        DispatchQueue.main.async {
            if self.isHidden == changeToVisible {
                self.text = text
                let originalClipToBounds = self.superview?.clipsToBounds ?? false
                self.superview?.clipsToBounds = true
                self.resizeAndReposition(changeToVisible)
                UIView.animate(withDuration: ChatNotAvailableLabel.kAnimationDuration, animations: {
                    let endingY = changeToVisible ? self.frame.height : (-1 * self.frame.height)
                    self.isHidden = !changeToVisible
                    self.frame.origin.y += endingY
                }, completion: { _ in
                    self.superview?.clipsToBounds = originalClipToBounds
                })
            }
        }
    }
}
