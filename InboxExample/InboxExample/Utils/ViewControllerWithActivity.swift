//
//  ViewControllerWithActivity.swift
//  InboxExample
//
//  Created by Andrey Kadochnikov on 26.05.2022.
//

import UIKit

let activityIndicatorTag = 18361950
let dimTag = 18361951

protocol ViewControllerWithActivity {
    func showActivityIndicator()
    func hideActivityIndicator(_ completion: (() -> Void)?)
    func dim(_ enabled: Bool, _ completion: (() -> Void)?)
}

extension UIViewController : ViewControllerWithActivity {
    func dim(_ enabled: Bool, _ completion: (() -> Void)?) {
        if enabled {
            var dim = self.view.viewWithTag(dimTag)
                
            if dim == nil {
                dim = UIView(frame: self.view.bounds)
                dim!.autoresizingMask = [.flexibleHeight, .flexibleWidth]
                dim!.backgroundColor = UIColor.black
                dim!.tag = dimTag
                dim!.alpha = 0
                self.view.addSubview(dim!)
            }
            
            UIView.animate(withDuration: 0.3, animations: {
                dim!.alpha = 0.7
            }, completion: { (_) in
                completion?()
            })
        } else {
            if let dim = self.view.viewWithTag(dimTag) {
                dim.removeFromSuperview()
                completion?()
            }
        }
        completion?()
    }
    func showActivityIndicator() {
        DispatchQueue.main.async {
            self.dim(true, {})
            self.prepareActivityIndicator().startAnimating()
        }
    }
    
    func hideActivityIndicator(_ completion: (() -> Void)?) {
        DispatchQueue.main.async {
            self.dim(false, completion)
            guard let activityIndicator = self.view.viewWithTag(activityIndicatorTag) as? UIActivityIndicatorView else {
                return
            }
            activityIndicator.stopAnimating()
        }
    }
    
    fileprivate func prepareActivityIndicator() -> UIActivityIndicatorView {
        
        if let activityIndicator = self.view.viewWithTag(activityIndicatorTag) as? UIActivityIndicatorView {
            return activityIndicator
        }
        
        let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
        activityIndicator.tag = activityIndicatorTag
        activityIndicator.color = UIColor.white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        guard let container = self.view.viewWithTag(dimTag) ?? self.view else {
            return activityIndicator
        }

        container.addSubview(activityIndicator)
        
        let width = NSLayoutConstraint(item: activityIndicator, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 100)
        let height = NSLayoutConstraint(item: activityIndicator, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 100)
        
        NSLayoutConstraint.activate([width, height])
        activityIndicator.addConstraints([width, height])
        
        let centerX = NSLayoutConstraint(item: activityIndicator, attribute: NSLayoutConstraint.Attribute.centerX, relatedBy: NSLayoutConstraint.Relation.equal, toItem: container, attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1, constant: 0)
        let centerY = NSLayoutConstraint(item: activityIndicator, attribute: NSLayoutConstraint.Attribute.centerY, relatedBy: NSLayoutConstraint.Relation.equal, toItem: container, attribute: NSLayoutConstraint.Attribute.centerY, multiplier: 1, constant: 0)
        
        NSLayoutConstraint.activate([centerX, centerY])
        container.addConstraints([centerX, centerY])
        return activityIndicator
    }
}
