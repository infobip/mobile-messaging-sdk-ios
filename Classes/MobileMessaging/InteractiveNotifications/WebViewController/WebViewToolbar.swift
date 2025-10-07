// 
//  WebViewToolbar.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

protocol WebViewToolbarDelegate {
	func webViewToolbarDidPressDismiss()
}

class WebViewToolbar: UIToolbar {

	var dismissDelegate: WebViewToolbarDelegate?
	lazy private var titleLabel: UILabel = UILabel(frame: CGRect.zero)

	var titleColor: UIColor? {
		set {
			titleLabel.textColor = newValue
		}
		get {
			return titleLabel.textColor
		}
	}

	var title: String? {
		set {
			titleLabel.text = newValue
			titleLabel.sizeToFit()
		}
		get {
			return titleLabel.text
		}
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		titleLabel.backgroundColor = UIColor.clear
		titleLabel.textAlignment = .center
		let dismissBtn = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(dismiss))
		let labelItem = UIBarButtonItem.init(customView: titleLabel)
		let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		self.setItems([flexible, labelItem, flexible, dismissBtn], animated: false)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc func dismiss() {
		dismissDelegate?.webViewToolbarDidPressDismiss()
	}
}
