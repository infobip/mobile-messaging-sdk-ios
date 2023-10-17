//
//  ButtonsView.swift
//  MobileMessaging
//
//  Created by Maksym Svitlovskyi on 20/09/2023.
//

import UIKit
#if WEBRTCUI_ENABLED
class CallControlButtonsView: UIView {
    
    struct LayoutConstants {
        static let buttonsHorizontalSpacing: CGFloat = 24
        static let buttonSize: CGFloat = 48
    }
    
    var contentStack: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.distribution = .equalSpacing
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        contentStack.spacing = LayoutConstants.buttonsHorizontalSpacing
        contentStack.alignment = .center
    }
    
    func addButton(
        content: VisibleCallButtonContent
    ) {
        let button = MMCallButton()
        button.set(content)
        content.button = button
        button.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(button)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: LayoutConstants.buttonSize),
            button.heightAnchor.constraint(equalToConstant: LayoutConstants.buttonSize)
        ])
    }
    
    func setButtons(
        content: [VisibleCallButtonContent]
    ) {
        contentStack.subviews.forEach { contentStack.removeArrangedSubview($0) }
        
        for buttonContent in content {
            addButton(content: buttonContent)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var intrinsicContentSize: CGSize {
        return CGSize(width: frame.width, height: 80)
    }
}

class MMCallButton: UIButton {
    
    private var content: VisibleCallButtonContent?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(touchDownAction(_:)), for: .touchDown)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = layer.bounds.width / 2
        clipsToBounds = true
    }
     
    func set(_ content: VisibleCallButtonContent) {
        self.content = content
        
        self.refreshContent()
    }
    
    private func refreshContent() {
        guard let content else { return }
        
        setBackgroundImage(.from(color: content.backgroundColor), for: .normal)
        
        if let selectedColor = content.selectedBackgroundColor {
            setBackgroundImage(.from(color: selectedColor), for: .selected)
        }
        
        setImage(content.icon, for: .normal)
        setImage(content.iconSelected, for: .selected)
    }
    
    @objc private func touchDownAction(_ button: UIButton) {
        content?.action(button)
    }
}

extension UIImage {
    static func from(color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context!.setFillColor(color.cgColor)
        context!.fill(rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img ?? UIImage()
    }
}
#endif
