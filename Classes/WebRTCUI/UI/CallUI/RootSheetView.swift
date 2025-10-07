// 
//  RootSheetView.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import UIKit
#if WEBRTCUI_ENABLED
class TopIndicatorView: UIView {
    override var intrinsicContentSize: CGSize {
        return CGSize(width: frame.width, height: 13)
    }
    
    lazy var indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = MMWebRTCSettings.sharedInstance.sheetDragIndicatorColor
        view.layer.cornerRadius = 1.5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = MMWebRTCSettings.sharedInstance.sheetBackgroundColor
        
        layer.masksToBounds = true
        layer.cornerRadius = 10
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(indicatorView)
    
        NSLayoutConstraint.activate([
            indicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicatorView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -3),
            indicatorView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.15),
            indicatorView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class RootSheetControllerContent: UIView {
    
    var topBarView: UIView = {
        let parentView = UIView()
        let view = TopIndicatorView()
        
        parentView.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            view.heightAnchor.constraint(equalToConstant: 20)
        ])
        parentView.backgroundColor = .clear
        return parentView
    }()
    
    lazy var mediumContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var largeContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupView() {
        addSubview(mediumContentView)
        addSubview(largeContentView)
        addSubview(topBarView)

        NSLayoutConstraint.activate([
            topBarView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            topBarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        NSLayoutConstraint.activate([
            mediumContentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mediumContentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mediumContentView.topAnchor.constraint(equalTo: topBarView.bottomAnchor),
            mediumContentView.bottomAnchor.constraint(equalTo: largeContentView.topAnchor),
        ])
        
        NSLayoutConstraint.activate([
            largeContentView.topAnchor.constraint(equalTo: mediumContentView.bottomAnchor),
            largeContentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            largeContentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            largeContentView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ])
    }
}

class RootSheetView: UIView {
    
    enum State {
        case hidden, mediumContent, fullContent
    }
    
    private var sheetState: State = .fullContent
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    public lazy var contentView: RootSheetControllerContent = {
        let view = RootSheetControllerContent()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    var stateDidChange: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .clear
        
        setupContainerView()
        setupViews()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setState(sheetState)
    }
        
    private func setupContainerView() {
        addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor)
        ])
    }
    
    lazy var contentViewBottomAnchor: NSLayoutConstraint = contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
    private func setupViews() {
        contentView.layer.masksToBounds = true
        containerView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentViewBottomAnchor
        ])
    }
        
    func newOffsetForState(_ state: State) -> CGFloat {
        switch state {
        case .fullContent: return 0
        case .mediumContent: return self.contentView.largeContentView.frame.height
        case .hidden: return self.contentView.largeContentView.frame.height + self.contentView.mediumContentView.frame.height
        }
    }
    
    func setState(_ state: State) {
        self.sheetState = state
        switch sheetState {
        case .fullContent:
            self.contentView.largeContentView.layer.opacity = 1
            self.contentView.mediumContentView.layer.opacity = 1
        case .mediumContent:
            self.contentView.largeContentView.layer.opacity = 0
            self.contentView.mediumContentView.layer.opacity = 1
        case .hidden:
            self.contentView.largeContentView.layer.opacity = 0
            self.contentView.mediumContentView.layer.opacity = 0
        }
        refreshOffset()
        stateDidChange?()
    }
    
    func refreshOffset() {
        self.contentViewBottomAnchor.constant = self.newOffsetForState(self.sheetState)
        self.layoutIfNeeded()
    }
    // MARK: Gestures
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let superHitTest = super.hitTest(point, with: event)
        if superHitTest === containerView {
            return nil
        }
        return superHitTest
    }
    
    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delaysTouchesBegan = false
        panGesture.delaysTouchesEnded = false
        contentView.topBarView.addGestureRecognizer(panGesture)
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        
        let pannedHeight = translation.y
        let currentY = newOffsetForState(self.sheetState)

        switch gesture.state {
        case .changed:
            
            self.contentView.largeContentView.layer.opacity = 1
            self.contentView.mediumContentView.layer.opacity = 1
            
            if pannedHeight + currentY <= newOffsetForState(.fullContent) { return }
            self.contentViewBottomAnchor.constant = pannedHeight + currentY
        case .ended:
            let expandedOffset = pannedHeight + currentY
            let fullContentDiff = newOffsetForState(.fullContent) - expandedOffset
            let mediumContentDiff = newOffsetForState(.mediumContent) - expandedOffset
            let hiddenContentDiff = newOffsetForState(.hidden) - expandedOffset

            let minOffset = min(
                abs(fullContentDiff), abs(mediumContentDiff), abs(hiddenContentDiff)
            )

            UIView.animate(withDuration: 0.2, animations: {
                if minOffset == abs(fullContentDiff) {
                    self.setState(.fullContent)
                } else if minOffset == abs(mediumContentDiff) {
                    self.setState(.mediumContent)
                } else {
                    self.setState(.hidden)
                }
            })
        default:
            break
        }
    }
}
#endif
