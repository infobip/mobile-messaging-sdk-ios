// 
//  LocalScreenshareView.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

#if WEBRTCUI_ENABLED
import Foundation
import UIKit

class LocalScreenshareView: UIView {
    lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = MMWebRTCSettings.sharedInstance.foregroundColor
        label.text = MMLoc.userSharingScreen
        return label
    }()
    
    lazy var button: UIButton = {
        let button = UIButton()
        let attributtedString = NSAttributedString(string: MMLoc.stopSharing, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        button.setAttributedTitle(attributtedString, for: .normal)
        button.setTitleColor(MMWebRTCSettings.sharedInstance.foregroundColor, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    var onStopScreenshareTap: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = MMWebRTCSettings.sharedInstance.localScreenshareBackgroundColor
        
        let stackView = UIStackView(arrangedSubviews: [label, button])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .center
        stackView.axis = .vertical
        stackView.spacing = 8
        
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -60),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
        
        button.addTarget(self, action: #selector(onButtonTap), for: .touchDown)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func onButtonTap() {
        onStopScreenshareTap?()
    }
}
#endif
