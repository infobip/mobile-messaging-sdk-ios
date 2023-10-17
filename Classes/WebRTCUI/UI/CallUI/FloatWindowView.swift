//
//  FloatWindowView.swift
//  MobileMessaging
//
//  Created by Maksym Svitlovskyi on 05/10/2023.
//
#if WEBRTCUI_ENABLED
import Foundation

class FloatingWindowView: UIView {
    
    private struct LayoutConstants {
        lazy var floatingWindowHeight: CGFloat = UIApplication.shared.statusBarOrientation.isLandscape ? UIScreen.main.bounds.width / 5 : UIScreen.main.bounds.height / 5
        lazy var floatingWindowWidth: CGFloat = (floatingWindowHeight / 16) * 9
    }

    private var layoutConstants = LayoutConstants()
    
    var bottomOffset: CGFloat = 0
    
    lazy var movingContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var movingContainerXAnchor: NSLayoutConstraint = movingContainer.centerXAnchor.constraint(equalTo: centerXAnchor)
    lazy var movingContainerYAnchor: NSLayoutConstraint = movingContainer.centerYAnchor.constraint(equalTo: centerYAnchor)
    lazy var movingContainerWidth: NSLayoutConstraint = movingContainer.widthAnchor.constraint(equalToConstant: layoutConstants.floatingWindowWidth)
    lazy var movingContainerHeight: NSLayoutConstraint = movingContainer.heightAnchor.constraint(equalToConstant: layoutConstants.floatingWindowHeight)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        addSubview(movingContainer)
        NSLayoutConstraint.activate([
            movingContainerHeight,
            movingContainerWidth,
            movingContainerXAnchor,
            movingContainerYAnchor
        ])
        
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        movingContainer.addGestureRecognizer(gesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup(with view: UIView?, secondView: UIView?) {
        if movingContainer.subviews.isEmpty {
            moveFloatingWindow(
                x: frame.width - movingContainer.frame.width/2,
                y: frame.height - movingContainer.frame.height/2 - safeAreaInsets.bottom/2
            )
        }
        movingContainer.subviews.forEach { $0.removeFromSuperview() }

        if view == nil, secondView == nil {
            self.movingContainer.isHidden = true
            return
        }
        
        if let firstView = view, let secondView = secondView {
            firstView.layer.masksToBounds = true
            secondView.layer.masksToBounds = true
            movingContainerWidth.constant = (layoutConstants.floatingWindowWidth + 2) * 2
            
            movingContainer.addSubview(firstView)
            movingContainer.addSubview(secondView)
            
            firstView.translatesAutoresizingMaskIntoConstraints = false
            secondView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                firstView.leadingAnchor.constraint(equalTo: movingContainer.leadingAnchor),
                firstView.topAnchor.constraint(equalTo: movingContainer.topAnchor),
                firstView.bottomAnchor.constraint(equalTo: movingContainer.bottomAnchor),
                firstView.widthAnchor.constraint(equalTo: movingContainer.widthAnchor, multiplier: 0.49)
            ])
            
            NSLayoutConstraint.activate([
                secondView.trailingAnchor.constraint(equalTo: movingContainer.trailingAnchor),
                secondView.topAnchor.constraint(equalTo: movingContainer.topAnchor),
                secondView.bottomAnchor.constraint(equalTo: movingContainer.bottomAnchor),
                secondView.widthAnchor.constraint(equalTo: movingContainer.widthAnchor, multiplier: 0.49)
            ])
            
            setFloatingWindowPosition(x: 0, y: frame.height / 2 - movingContainer.frame.height / 2 - bottomOffset)
            self.movingContainer.isHidden = false && PIPKit.isPIP

            return
        }
        
        if let firstView = view {
            setup(view: firstView)
            return
        }
        
        if let secondView = secondView {
            setup(view: secondView)
            return
        }
    }
    
    private func setup(view: UIView) {
        movingContainerWidth.constant = layoutConstants.floatingWindowWidth
        movingContainer.addSubview(view)
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: movingContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: movingContainer.trailingAnchor),
            view.topAnchor.constraint(equalTo: movingContainer.topAnchor),
            view.bottomAnchor.constraint(equalTo: movingContainer.bottomAnchor)
        ])
        self.movingContainer.isHidden = false && PIPKit.isPIP
    }
    
    lazy var currentOrigin = (x: movingContainerXAnchor.constant, y: movingContainerYAnchor.constant)
    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {

        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .changed:
            moveContainer(x: translation.x, y: translation.y, in: frame.size)
        case .ended: return
            currentOrigin = (movingContainerXAnchor.constant, movingContainerYAnchor.constant)
        default:
            break
        }
    }

    func moveFloatingWindow(x: CGFloat, y: CGFloat) {
        moveContainer(x: x, y: y, in: frame.size)
        currentOrigin = (movingContainerXAnchor.constant, movingContainerYAnchor.constant)
    }
    
    func setFloatingWindowPosition(x: CGFloat, y: CGFloat) {
        movingContainerXAnchor.constant = x
        movingContainerYAnchor.constant = y
        currentOrigin = (movingContainerXAnchor.constant, movingContainerYAnchor.constant)
    }
    
    func refreshWithCurrentPositionToBounds() {
        moveFloatingWindow(x: movingContainerXAnchor.constant, y: movingContainerYAnchor.constant)
    }
    
    private func moveContainer(
        x: CGFloat, y: CGFloat,
        in size: CGSize
    ) {
        var newX = currentOrigin.x + x
        var newY = currentOrigin.y + y
        
        let leadingBound = size.width / 2 - movingContainer.frame.width / 2
        let trailingBound = -(size.width / 2) + movingContainer.frame.width / 2
        if newX > leadingBound {
            newX = leadingBound
        } else if newX < trailingBound {
            newX = trailingBound
        }
        
        let topBound = -(size.height / 2) + (safeAreaInsets.top + movingContainer.frame.height / 2)
        let bottomBound = size.height / 2 - safeAreaInsets.bottom - movingContainer.frame.height / 2 - bottomOffset
        if newY < topBound {
            newY = topBound
        } else if newY > bottomBound {
            newY = bottomBound
        }
    
        movingContainerXAnchor.constant = newX
        movingContainerYAnchor.constant = newY
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let superHitTest = super.hitTest(point, with: event)
        
        if superHitTest == self {
            return nil
        }
        return superHitTest
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        let widthRatioPosition = currentOrigin.x / frame.width
        let heightRatioPosition = currentOrigin.y / frame.height
        
        let newX = widthRatioPosition * frame.height
        let newY = heightRatioPosition * frame.width
        
        setFloatingWindowPosition(x: newX, y: newY)
    }
}
#endif
