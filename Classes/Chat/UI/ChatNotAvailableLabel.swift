//
//  ChatNoConnectionLabel.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 11.06.2020.
//

import Foundation

class ChatNotAvailableLabel: UILabel {
    static var kHeight: CGFloat = 40.0
    static var kAnimationDuration: TimeInterval = 0.5
    var isShown = false

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
        font = UIFont.systemFont(ofSize: 16)
        text = ChatLocalization.localizedString(forKey: "mm_no_connection_label", defaultString: "No connection")
        backgroundColor = .lightGray
        autoresizingMask = [.flexibleWidth]
    }
    
    func show() {
        if !isShown {
            UIView.animate(withDuration: ChatNotAvailableLabel.kAnimationDuration) {
                self.frame.origin.y += self.frame.height
            }
        }
        isShown = true
    }
    
    func hide() {
        if isShown {
            UIView.animate(withDuration: ChatNotAvailableLabel.kAnimationDuration) {
                self.frame.origin.y -= self.frame.height
            }
        }
        isShown = false
    }
}
