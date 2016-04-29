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

/**
Push notifications handling
- shows alert, if `alert` exists in userInfo
- plays sound or vibrate, if `sound` exists in userInfo
- changes application badge, if `badge` exists
 */
class MMPush {
    
    /**
     Handles notification
     
     - shows alert, if `alert` exists in userInfo
     - plays sound or vibrate, if `sound` exists in userInfo
     - changes application badge, if `badge` exists

     - parameter userInfo: userInfo of type `[NSObject : AnyObject]` from push notification
    */
    class func handlePush(userInfo: [NSObject: AnyObject]) {
        guard let aps = userInfo[MMAPIKeys.kAps] else {
            MMLogError("IBMMPush: Can't parse payload")
            return
        }
        
        var appName = NSBundle.mainBundle().infoDictionary?["CFBundleName"]
        
        if let alert = aps[MMAPIKeys.kAlert] as? String,
            appName = appName as? String {
                MMAlert.showAlert(appName, message: alert, animated: true, cancelActionCompletion: { (action) -> Void in
                    MMLogInfo("IBMMPush: \(alert) Closed")
                })
        } else if let body = (aps[MMAPIKeys.kAlert] as? [String: AnyObject])?[MMAPIKeys.kBody] as? String {
            if let title = (aps[MMAPIKeys.kAlert] as? [String: AnyObject])?[MMAPIKeys.kTitle] as? String {
                appName = title
            }
            
            if let appName = appName as? String {
                MMAlert.showAlert(appName, message: body, animated: true, cancelActionCompletion: { (action) -> Void in
                    MMLogInfo("MMPush: \(appName) \(body) Closed")
                })
            }
        }
        
        
        if let badgeNumber = aps[MMAPIKeys.kBadge],
           let number = badgeNumber?.integerValue {
                UIApplication.sharedApplication().applicationIconBadgeNumber = number
        }
        
        if let sound = aps[MMAPIKeys.kSound] as? String {
            if sound == "default" {
                playVibrate()
            } else {
                playSound(sound)
            }
        }
    }
    
    //MARK: Sound
    private class func playVibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    private class func playSound(name: String) {
        let name = NSString(string: name)
        if let soundURL = NSBundle.mainBundle().URLForResource(name.stringByDeletingPathExtension, withExtension:name.pathExtension) {
            var soundId: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(soundURL, &soundId)
            AudioServicesPlaySystemSound(soundId);
        }
    }
}

private class MMAlert {
    static let operationQueue : NSOperationQueue = {
        let opQueue = NSOperationQueue()
        opQueue.maxConcurrentOperationCount = 1
        return opQueue
    }()
    
    class func showAlert(title:String, message: String, animated:Bool, cancelActionCompletion:(UIAlertAction) -> Void) {
        let operation = MMAlertOperation(title: title, message: message, animated: animated, cancelActionCompletion: cancelActionCompletion)
        operationQueue.addOperation(operation)
    }
}

final class MMAlertOperation : Operation {
    static let kCancelButtonTitle = "OK"
    
    var alertController: UIAlertController
    let title: String
    let message: String
    let animated: Bool
    
	override func execute() {
		MMQueue.Main.queue.executeAsync {
			self.showAlertController(self.alertController, completion: { () -> Void in
				self.finish()
			})
		}
    }
	
    private init(title: String, message: String, animated:Bool, cancelActionCompletion:(UIAlertAction) -> Void){
        self.title = title
        self.message = message
        self.animated = animated
        self.alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        
        let action = UIAlertAction(title: MMAlertOperation.kCancelButtonTitle, style: .Cancel) { (action) -> Void in
            cancelActionCompletion(action)
        }
        
        alertController.addAction(action)
    }
    
    private func showAlertController(alertController: UIAlertController, completion:() -> Void) {
        guard var rootViewController = UIApplication.sharedApplication().keyWindow?.rootViewController else {
            return
        }
        
        while let presentedViewController = rootViewController.presentedViewController {
            rootViewController = presentedViewController
        }
        
        rootViewController.presentViewController(alertController, animated: animated, completion: completion)
    }
}