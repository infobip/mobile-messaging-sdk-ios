//
//  MMPush.swift
//  MobileMessaging
//
//  Created by Andrey K. on 29/02/16.
//  
//

import Foundation
import AVFoundation
import UIKit

public final class MMPush: NSObject {
    
    /**
     Handles the remote notification in following way:
     - displays an alert for the remote notification payload
     - plays sound or vibrate, if `sound` is set
     - changes application badge, if `badge` is set

     - parameter userInfo: a dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
    */
    public class func handlePush(userInfo: [AnyHashable: Any]) {
        guard let aps = userInfo[MMAPIKeys.kAps] as? [AnyHashable: Any] else {
            MMLogError("IBMMPush: Can't parse payload")
            return
        }
        
        var appName = Bundle.main.infoDictionary?["CFBundleName"]
        
        if let alert = aps[MMAPIKeys.kAlert as String] as? String,
            let appName = appName as? String {
                MMAlert.showAlert(title: appName, message: alert, animated: true, cancelActionCompletion: nil)
        } else if let body = (aps[MMAPIKeys.kAlert] as? [String: AnyObject])?[MMAPIKeys.kBody] as? String {
            if let title = (aps[MMAPIKeys.kAlert] as? [String: AnyObject])?[MMAPIKeys.kTitle] as? String {
                appName = title
            }
			
            if let appName = appName as? String {
                MMAlert.showAlert(title: appName, message: body, animated: true, cancelActionCompletion: nil)
            }
        }
		
        if let badgeNumber = aps[MMAPIKeys.kBadge] as AnyObject?,
           let number = badgeNumber.integerValue {
                UIApplication.shared.applicationIconBadgeNumber = number
        }
        
        if let sound = aps[MMAPIKeys.kSound] as? String {
            if sound == "default" {
                playVibrate()
            } else {
                playSound(name: sound)
            }
        }
    }
    
    //MARK: Sound
    private class func playVibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    private class func playSound(name: String) {
        let name = NSString(string: name)
        if let soundURL = Bundle.main.url(forResource: name.deletingPathExtension, withExtension:name.pathExtension) {
            var soundId: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundId)
            AudioServicesPlaySystemSound(soundId);
        }
    }
}

private class MMAlert {
    static let operationQueue : OperationQueue = {
        let opQueue = OperationQueue()
        opQueue.maxConcurrentOperationCount = 1
        return opQueue
    }()
    
    class func showAlert(title:String, message: String, animated:Bool, cancelActionCompletion:((UIAlertAction) -> Void)?) {
        let operation = MMAlertOperation(title: title, message: message, animated: animated, cancelActionCompletion: cancelActionCompletion)
        operationQueue.addOperation(operation)
    }
}

fileprivate final class MMAlertOperation : Operation {
    static let kCancelButtonTitle = "OK"
    
    let alertController: UIAlertController
    let title: String
    let message: String
    let animated: Bool
    
	override func execute() {
		MMQueue.Main.queue.executeAsync {
			self.showAlertController(self.alertController, completion: { Void -> Void in
				self.finish()
			})
		}
    }
	
	init(title: String, message: String, animated:Bool, cancelActionCompletion:((UIAlertAction) -> Void)?){
        self.title = title
        self.message = message
        self.animated = animated
        self.alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let action = UIAlertAction(title: MMAlertOperation.kCancelButtonTitle, style: .cancel) { (action) -> Void in
            cancelActionCompletion?(action)
        }
        
        alertController.addAction(action)
    }
    
    private func showAlertController(_ alertController: UIAlertController, completion: @escaping (Void) -> Void) {
        guard var rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
            return
        }
        
        while let presentedViewController = rootViewController.presentedViewController {
            rootViewController = presentedViewController
        }
		
        rootViewController.present(alertController, animated: animated, completion: completion)
    }
}
