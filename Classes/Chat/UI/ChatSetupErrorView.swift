//
//  ChatSetupErrorView.swift
//  MobileMessaging
//
// Copyright (c) 2016-2026 Infobip Limited
// Licensed under the Apache License, Version 2.0
//

import UIKit

class ChatSetupErrorView: UIView {

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var imageViewTopConstraint = NSLayoutConstraint()

    private var settings: MMChatSettings? {
        MMChatSettings.sharedInstance
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func setupView() {
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        imageViewTopConstraint = imageView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: bounds.height * 0.2)

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 310),
            imageView.heightAnchor.constraint(equalToConstant: 150),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageViewTopConstraint,

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.heightAnchor.constraint(equalToConstant: 40),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])

        isHidden = true
        alpha = 0
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageViewTopConstraint.constant = bounds.height * 0.2 // needed for screen rotation
    }

    func configure(title: String?, subtitle: String?) {
        let image = settings?.fullScreenErrorImage ?? UIImage(mm_chat_named: "mmChatNoWidgetIcon")
        backgroundColor = settings?.fullScreenErrorBackgroundColor ?? MMChatBEPO.colorBackgroundPrimary
        imageView.image = image
        imageView.isHidden = image == nil
        titleLabel.text = title
        titleLabel.textColor =  settings?.fullScreenErrorTitleTextColor ?? MMChatBEPO.colorTextPrimary
        titleLabel.isHidden = title == nil
        subtitleLabel.text = subtitle
        subtitleLabel.textColor = settings?.fullScreenErrorSubtitleTextColor ?? MMChatBEPO.colorTextSubdued
        subtitleLabel.isHidden = subtitle == nil
    }

    func setVisible(_ visible: Bool, animated: Bool = true) {
        guard visible != !isHidden else { return }

        if visible {
            isHidden = false
        }

        let animations = { self.alpha = visible ? 1.0 : 0.0 }
        let completion: (Bool) -> Void = { _ in
            if !visible { self.isHidden = true }
        }

        if animated {
            UIView.animate(withDuration: 0.3, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }
}
