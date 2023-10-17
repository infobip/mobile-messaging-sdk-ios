//
//  MediaCallViewHeader.swift
//  MobileMessaging
//
//  Created by Maksym Svitlovskyi on 05/10/2023.
//
#if WEBRTCUI_ENABLED
import UIKit

class MediaCallViewHeader: UIView {
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = MMWebRTCSettings.sharedInstance.foregroundColor
        return label
    }()
    
    lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = MMWebRTCSettings.sharedInstance.foregroundColor
        return label
    }()
    
    lazy var dividerView: UIView = {
        let divider = UIView()
        divider.backgroundColor = MMWebRTCSettings.sharedInstance.foregroundColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        return divider
    }()
    
    lazy var headerStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            micIcon, nameLabel, dividerView, timeLabel
        ])
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 8
        stackView.alignment = .center
        return stackView
    }()
    
    lazy var micIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = MMWebRTCSettings.sharedInstance.iconMutedParticipant
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var collapseButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(MMWebRTCSettings.sharedInstance.iconCollapse, for: .normal)
        button.setImage(MMWebRTCSettings.sharedInstance.iconExpand, for: .selected)
        return button
    }()
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = MMWebRTCSettings.sharedInstance.backgroundColor
        
        addSubview(collapseButton)
        
        NSLayoutConstraint.activate([
            collapseButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            collapseButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 4),
            collapseButton.heightAnchor.constraint(equalToConstant: 30),
            collapseButton.widthAnchor.constraint(equalToConstant: 30)
        ])
        
        addSubview(headerStack)
        
        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: collapseButton.leadingAnchor),
            headerStack.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.6),
            headerStack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            nameLabel.widthAnchor.constraint(lessThanOrEqualTo: headerStack.widthAnchor, multiplier: 0.7)
        ])

        NSLayoutConstraint.activate([
            dividerView.centerYAnchor.constraint(equalTo: headerStack.centerYAnchor),
            dividerView.heightAnchor.constraint(equalTo: headerStack.heightAnchor, multiplier: 0.5),
            dividerView.widthAnchor.constraint(equalToConstant: 1),
            micIcon.heightAnchor.constraint(equalTo: headerStack.heightAnchor, multiplier: 0.65),
            micIcon.widthAnchor.constraint(equalTo: headerStack.heightAnchor, multiplier: 0.65)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
