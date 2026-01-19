// 
//  MMPopOverBar.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import UIKit
private let kGap: CGFloat = 8.0

fileprivate class PopOverBaseView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in subviews.reversed() {
            let convertedPoint = subview.convert(point, from: self)
            if subview.bounds.contains(convertedPoint) {
                return subview.hitTest(convertedPoint, with: event)
            }
        }
        return nil
    }
}

public final class MMPopOverBar {
    public static let shared = MMPopOverBar()
    private static let kWindowLevel: UIWindow.Level = UIWindow.Level(UIWindow.Level.statusBar.rawValue + 1)
    private var popoversViews: [MMPopoverView] = [] {
        didSet {
            if let popoverView = popoversViews.first, popoverView.state == .queued {
                show(popoverView)
            }
        }
    }
    private var options = Options(shouldConsiderSafeArea: true, isStretchable: true, textAlignment: .left)
    private var baseView = PopOverBaseView()
    private var safeArea: UIEdgeInsets {
        let window = UIApplication.shared.mmkeyWindow
        return window?.safeAreaInsets ?? .zero
    }

    public struct Options {
        let shouldConsiderSafeArea: Bool
        let isStretchable: Bool
        let textAlignment: NSTextAlignment
        let font: UIFont

        public init(
            shouldConsiderSafeArea: Bool = true,
            isStretchable: Bool = false,
            textAlignment: NSTextAlignment = .natural,
            font: UIFont = UIFont.systemFont(ofSize: 14.0)) {
            self.shouldConsiderSafeArea = shouldConsiderSafeArea
            self.isStretchable = isStretchable
            self.textAlignment = textAlignment
            self.font = font
        }
    }

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.deviceRotated),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    public func setDefault(options: Options) {
        self.options = options
    }

    public func show(textColor: UIColor,
                     backgroundColor: UIColor,
                     icon: UIImage? = nil,
                     iconTint: UIColor,
                     message: String,
                     duration: TimeInterval = 3,
                     hideOnTap: Bool = true,
                     options: Options? = nil,
                     completion: (() -> Void)? = nil,
                     presenterVC: UIViewController) {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self = self else { return }
            let currentOptions = options ?? self.options
            let noSafeArea = presenterVC.view.safeAreaLayoutGuide.layoutFrame == .zero
            self.baseView.frame = noSafeArea ? presenterVC.view.bounds : presenterVC.view.safeAreaLayoutGuide.layoutFrame
            self.baseView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            presenterVC.view.addSubview(self.baseView)
            let popoverView = MMPopoverView(frame: .zero, icon: icon, hideOnTap: hideOnTap)
            popoverView.backgroundColor = backgroundColor
            popoverView.messageLabel.textColor = textColor
            popoverView.messageLabel.text = message
            popoverView.iconImageV.tintColor = iconTint
            popoverView.messageLabel.numberOfLines = currentOptions.isStretchable ? 0 : 1
            popoverView.messageLabel.textAlignment = currentOptions.textAlignment
            popoverView.messageLabel.font = currentOptions.font
            popoverView.shouldConsiderSafeArea = currentOptions.shouldConsiderSafeArea
            popoverView.duration = duration
            self.appendUnique(popoverView)
        }
    }
    
    private func appendUnique(_ popoverView: MMPopoverView) {
        // we will avoid cases where the same error banner is queued more than once
        guard self.popoversViews.filter({ $0.messageLabel.text == popoverView.messageLabel.text }).isEmpty else { return }
        self.popoversViews.append(popoverView)
    }

    private func show(_ popoverView: MMPopoverView) {
        let statusBarHeight: CGFloat = max(48.0, safeArea.top)
        let alertBarHeight: CGFloat = max(statusBarHeight, popoverView.frame.height)
        self.baseView.addSubview(popoverView)
        popoverView.frame.size.width = self.baseView.bounds.width
        popoverView.autoresizingMask = [.flexibleWidth]
        popoverView.fit(safeArea: self.safeArea)
        popoverView.show(duration: popoverView.duration, translationY: -alertBarHeight) {
            if let index = self.popoversViews.firstIndex(of: popoverView) {
                self.popoversViews.remove(at: index)
                if self.popoversViews.isEmpty {
                    self.baseView.removeFromSuperview()
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc public func deviceRotated() {
        DispatchQueue.mmEnsureMain {
            if let popoverView = self.popoversViews.first, popoverView.state == .showing {
                popoverView.fit(safeArea: self.safeArea)
            }
        }
    }
}

// MARK: - Static helpers

public extension MMPopOverBar {
    static func setDefault(options: Options) {
        shared.options = options
    }

    static func show(
        textColor: UIColor,
        backgroundColor: UIColor,
        icon: UIImage? = nil,
        iconTint: UIColor,
        message: String,
        duration: TimeInterval = 3,
        hideOnTap: Bool = true,
        options: Options? = nil, completion: (() -> Void)? = nil,
        presenterVC: UIViewController) {
            shared.show(
                textColor: textColor,
                backgroundColor: backgroundColor,
                icon: icon,
                iconTint: iconTint,
                message: message,
                duration: duration,
                hideOnTap: hideOnTap,
                options: options,
                completion: completion,
                presenterVC: presenterVC)
    }

    static func hide(with animation: Bool = false) {
        DispatchQueue.mmEnsureMain {
            shared.popoversViews.forEach({ $0.hide(with: animation) })
        }
    }
}

internal class MMPopoverView: UIView {
    internal let messageLabel = UILabel()
    internal let iconImageV = UIImageView()
    private let contentStackView = UIStackView()
    private var stackTopConstraint: NSLayoutConstraint?
    private var stackLeadingConstraint: NSLayoutConstraint?
    private var stackTrailingConstraint: NSLayoutConstraint?

    internal enum State {
        case showing,
             hiding,
             hidden,
             queued
    }

    private static let kAnimationDuration: TimeInterval = 0.2
    private var translationY: CGFloat = 0
    private var completion: (() -> Void)?
    internal var state: State = .queued
    internal var duration: TimeInterval = .zero
    internal var shouldConsiderSafeArea: Bool = true

    required public init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }

    public init(frame: CGRect, icon: UIImage?, hideOnTap: Bool = true) {
        super.init(frame: frame)
        iconImageV.image = icon

        setupStackView()

        if hideOnTap {
            let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hide))
            addGestureRecognizer(gestureRecognizer)
        }
    }

    private func setupStackView() {
        iconImageV.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        contentStackView.spacing = kGap

        contentStackView.addArrangedSubview(iconImageV)
        contentStackView.addArrangedSubview(messageLabel)
        addSubview(contentStackView)

        stackTopConstraint = contentStackView.topAnchor.constraint(equalTo: topAnchor, constant: kGap)
        stackLeadingConstraint = contentStackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: kGap)
        stackTrailingConstraint = contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -kGap)

        NSLayoutConstraint.activate([
            iconImageV.widthAnchor.constraint(equalToConstant: 24),
            iconImageV.heightAnchor.constraint(equalToConstant: 24),
            contentStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackTopConstraint!,
            stackLeadingConstraint!,
            stackTrailingConstraint!
        ])
    }

    func fit(safeArea: UIEdgeInsets) {
        let shouldAddSafeAreaToY = shouldConsiderSafeArea || (UIDevice.current.orientation == .landscapeRight || UIDevice.current.orientation == .landscapeLeft)
        let topPadding = shouldAddSafeAreaToY ? safeArea.top + kGap : kGap

        // Update constraint constants for safe areas
        stackTopConstraint?.constant = topPadding
        stackLeadingConstraint?.constant = kGap + safeArea.left
        stackTrailingConstraint?.constant = -(kGap + safeArea.right)

        // Calculate available width for content (accounting for safe areas and padding)
        let availableWidth = frame.size.width - 2 * kGap - safeArea.left - safeArea.right

        // Set maximum width for label to allow wrapping
        let maxLabelWidth = availableWidth - 24 - kGap // 24 is icon width
        messageLabel.preferredMaxLayoutWidth = maxLabelWidth

        // Force layout to calculate height
        layoutIfNeeded()

        // Set view height based on content
        frame.size.height = topPadding + contentStackView.frame.height + kGap
    }

    func show(duration: TimeInterval, translationY: CGFloat, completion: (() -> Void)?) {
        self.state = .showing
        self.translationY = translationY
        self.completion = completion

        transform = CGAffineTransform(translationX: 0, y: translationY)
        UIView.animate(
            withDuration: MMPopoverView.kAnimationDuration,
            animations: { () -> Void in
                self.transform = .identity
        }, completion: { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(duration))) {
                self?.hide()
            }
        })
    }

    @objc func hide(with animation: Bool = true) {
        guard state == .showing else {
            return
        }
        self.state = .hiding
        // Hide animation
        UIView.animate(
            withDuration: animation ? MMPopoverView.kAnimationDuration : 0,
            animations: { () -> Void in
                self.transform = CGAffineTransform(translationX: 0, y: self.translationY)
        },
            completion: { _ -> Void in
                self.removeFromSuperview()
                self.state = .hidden
                self.completion?()
                self.completion = nil
        })
    }
}
