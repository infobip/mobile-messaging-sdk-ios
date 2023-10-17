//
//  CallView.swift
//  MobileMessaging
//
//  Created by Maksym Svitlovskyi on 22/09/2023.
//

import UIKit
#if WEBRTCUI_ENABLED
class VoiceCallView: UIView {
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 24) // Add font customization
        label.textAlignment = .center
        label.textColor = MMWebRTCSettings.sharedInstance.foregroundColor
        return label
    }()
    
    lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = MMWebRTCSettings.sharedInstance.textSecondaryColor
        return label
    }()
    
    lazy var placeholderImage: UIImageView = {
        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.image = MMWebRTCSettings.sharedInstance.iconAvatar
        image.contentMode = .scaleAspectFit
        return image
    }()
    
    lazy var collapseButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(MMWebRTCSettings.sharedInstance.iconCollapse, for: .normal)
        button.setImage(MMWebRTCSettings.sharedInstance.iconExpand, for: .selected)
        return button
    }()
    
    lazy var micIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = MMWebRTCSettings.sharedInstance.iconMutedParticipant
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var topConstraint: NSLayoutConstraint = titleLabel.topAnchor.constraint(equalTo: collapseButton.bottomAnchor, constant: 50)

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = MMWebRTCSettings.sharedInstance.backgroundColor
        
        addSubview(titleLabel)
        addSubview(statusLabel)
        addSubview(placeholderImage)
        addSubview(collapseButton)
        addSubview(micIcon)
        
        NSLayoutConstraint.activate([
            collapseButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            collapseButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 4),
            collapseButton.heightAnchor.constraint(equalToConstant: 30),
            collapseButton.widthAnchor.constraint(equalToConstant: 30)
        ])
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            topConstraint
        ])
        
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5)
        ])
        
        NSLayoutConstraint.activate([
            placeholderImage.topAnchor.constraint(equalTo: micIcon.bottomAnchor, constant: 0),
            placeholderImage.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholderImage.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.45)
        ])
        
        NSLayoutConstraint.activate([
            micIcon.centerXAnchor.constraint(equalTo: centerXAnchor),
            micIcon.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func pipLayout(isPIP: Bool) {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveLinear], animations: { [weak self] in
            self?.topConstraint.constant = isPIP ? 0 : 50
            self?.placeholderImage.isHidden = isPIP
            self?.layoutIfNeeded()
        })
    }
}
#endif
