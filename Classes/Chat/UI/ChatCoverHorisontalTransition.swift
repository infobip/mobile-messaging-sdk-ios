//
//  ChatCoverHorisontalTransition.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 22.08.2020.
//

import Foundation

class ChatCoverHorisontalTransition: NSObject, UIViewControllerAnimatedTransitioning {
    var dismiss: Bool
    let duration = 0.25
    
    init(dismiss: Bool) {
        self.dismiss = dismiss
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from),
            let toVC = transitionContext.viewController(forKey: .to) else {
                return
        }
        let containerView = transitionContext.containerView
        var frame = containerView.bounds
        frame.origin = CGPoint(x: frame.width, y: 0)
        containerView.addSubview(toVC.view)
        
        if dismiss {
            containerView.bringSubviewToFront(fromVC.view)
            View.animate(withDuration: duration, animations: {
                fromVC.view.frame = frame
            }) { (finished) in
                containerView.superview?.addSubview(toVC.view)
                fromVC.view.removeFromSuperview()
                transitionContext.completeTransition(true)
            }
        } else {
            toVC.view.frame = frame
            View.animate(withDuration: duration, animations: {
                toVC.view.center = containerView.center
            }) { (finished) in
                transitionContext.completeTransition(true)
            }
        }
    }
}

class ChatCustomTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ChatCoverHorisontalTransition(dismiss: true)
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ChatCoverHorisontalTransition(dismiss: false)
    }
}
