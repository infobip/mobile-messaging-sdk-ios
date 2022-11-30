//
//  MMPopOverBar.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 13/04/2021.
//  Copyright © 2021 Infobip Ltd. All rights reserved.
//

import UIKit

public final class MMPopOverBar {
    public static let shared = MMPopOverBar()
    private static let kWindowLevel: UIWindow.Level = UIWindow.Level(UIWindow.Level.statusBar.rawValue + 1)
    private var popoversViews: [PopoverView] = []
    private var options = Options(shouldConsiderSafeArea: true, isStretchable: false, textAlignment: .left)

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

    public func setDefault(options: Options) {
        self.options = options
    }

    public func show(backgroundColor: UIColor, 
                     textColor: UIColor,
                     message: String, 
                     duration: TimeInterval = 3,
                     options: Options? = nil, 
                     completion: (() -> Void)? = nil,
                     presenterVC: UIViewController) {
        DispatchQueue.main.async {
            // Hide all before new one is shown.
            self.popoversViews.forEach({ $0.hide() })
            let currentOptions = options ?? self.options
            let width = UIScreen.main.bounds.width
            let height = UIScreen.main.bounds.height
            let baseView = UIView(frame: UIScreen.main.bounds)
            let orientation = UIApplication.shared.statusBarOrientation
            let userInterfaceIdiom = UIDevice.current.userInterfaceIdiom
            if orientation.isLandscape {
                if userInterfaceIdiom == .phone {
                    let sign: CGFloat = orientation == .landscapeLeft ? -1 : 1
                    let d = abs(width - height) / 2
                    baseView.transform = CGAffineTransform(
                        rotationAngle: sign * CGFloat.pi / 2).translatedBy(x: sign * d, y: sign * d)
                }
            } else {
                if userInterfaceIdiom == .phone && orientation == .portraitUpsideDown {
                    baseView.transform = CGAffineTransform(rotationAngle: .pi)
                }
            }
            baseView.isUserInteractionEnabled = false
            presenterVC.view.addSubview(baseView)

            let window = UIApplication.shared.keyWindow
            let safeArea: UIEdgeInsets  = window?.safeAreaInsets ?? .zero
            let popoverView = PopoverView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0))
            popoverView.backgroundColor = backgroundColor
            popoverView.messageLabel.textColor = textColor
            popoverView.messageLabel.text = message
            popoverView.messageLabel.numberOfLines = currentOptions.isStretchable ? 0 : 1
            popoverView.messageLabel.textAlignment = currentOptions.textAlignment
            popoverView.messageLabel.font = currentOptions.font
            popoverView.fit(safeArea: currentOptions.shouldConsiderSafeArea ? safeArea : .zero)
            self.popoversViews.append(popoverView)
            baseView.addSubview(popoverView)

            let statusBarHeight: CGFloat = max(48.0, safeArea.top)
            let alertBarHeight: CGFloat = max(statusBarHeight, popoverView.frame.height)
            popoverView.show(duration: duration, translationY: -alertBarHeight) {
                if let index = self.popoversViews.firstIndex(of: popoverView) {
                    self.popoversViews.remove(at: index)
                }
                completion?()
            }
        }
    }
}

// MARK: - Static helpers

public extension MMPopOverBar {
    static func setDefault(options: Options) {
        shared.options = options
    }

    static func show(backgroundColor: UIColor, textColor: UIColor, message: String, duration: TimeInterval = 3, 
                     options: Options? = nil, completion: (() -> Void)? = nil, presenterVC: UIViewController) {
        shared.show(backgroundColor: backgroundColor, 
                    textColor: textColor, message: message, duration: duration, 
                    options: options, completion: completion, presenterVC: presenterVC)
    }
    
    static func hide() {
        DispatchQueue.main.async {
            shared.popoversViews.forEach({ $0.hide() })
        }
    }
}

internal class PopoverView: UIView {
    func applySettings() {
        iconImageV.image = MMWebRTCSettings.sharedInstance.iconAlert
    }

    internal let messageLabel = UILabel()
    internal let iconImageV = UIImageView()

    private enum State {
        case showing
        case shown
        case hiding
        case hidden
    }

    private static let kMargin: CGFloat = MMWebRTCUIConstants.margin
    private static let kAnimationDuration: TimeInterval = 0.2

    private var translationY: CGFloat = 0
    private var completion: (() -> Void)?
    private var state: State = .hidden

    required public init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let margin = MMWebRTCUIConstants.margin
        iconImageV.frame = CGRect(x: margin, 
                                  y: margin, 
                                  width: 24, 
                                  height: 24)
        applySettings()
        messageLabel.frame = CGRect(x: iconImageV.frame.size.width + margin, 
                                    y: margin, 
                                    width: frame.width - margin*2 - iconImageV.frame.size.width, 
                                    height: frame.height - margin*2)
        addSubview(messageLabel)
        addSubview(iconImageV)
    }

    func fit(safeArea: UIEdgeInsets) {
        let margin = PopoverView.kMargin
        messageLabel.sizeToFit()
        messageLabel.frame.origin.x = iconImageV.frame.size.width + 2*margin + safeArea.left
        messageLabel.frame.origin.y = margin + safeArea.top
        messageLabel.frame.size.width = frame.size.width - margin*2 - safeArea.left - 
            safeArea.right - iconImageV.frame.size.width
        frame.size.height = messageLabel.frame.origin.y + messageLabel.frame.height + margin*2
        iconImageV.center.y = messageLabel.center.y
    }

    deinit {
        print("popoverView deinit")
    }

    func show(duration: TimeInterval, translationY: CGFloat, completion: (() -> Void)?) {
        self.state = .showing
        self.translationY = translationY
        self.completion = completion

        transform = CGAffineTransform(translationX: 0, y: translationY)
        UIView.animate(
            withDuration: PopoverView.kAnimationDuration,
            animations: { () -> Void in
                self.transform = .identity
        }, completion: { _ in
            self.state = .shown
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(duration))) {
                self.hide()
            }
        })
    }

    func hide() {
        guard state == .showing || state == .shown else {
            return
        }
        self.state = .hiding
        // Hide animation
        UIView.animate(
            withDuration: PopoverView.kAnimationDuration,
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
