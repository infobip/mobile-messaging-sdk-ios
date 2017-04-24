//
//  MMApplicationListener.swift
//  MobileMessaging
//
//  Created by Andrey K. on 24/02/16.
//  
//

import Foundation

final class MMApplicationListener: NSObject {
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
	init(mmContext: MobileMessaging) {
		self.mmContext = mmContext
        super.init()
		
		NotificationCenter.default.addObserver(self, selector: #selector(MMApplicationListener.handleAppWillEnterForegroundNotification), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(MMApplicationListener.handleAppDidFinishLaunchingNotification(n:)), name: NSNotification.Name.UIApplicationDidFinishLaunching, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(MMApplicationListener.handleGeoServiceDidStartNotification), name: NSNotification.Name(rawValue: MMNotificationGeoServiceDidStart), object: nil)
		
    }
	
	//MARK: Internal
	func handleAppWillEnterForegroundNotification() {
		mmContext?.sync()
	}
	
	func handleAppDidFinishLaunchingNotification(n: Notification) {
		guard n.userInfo?[UIApplicationLaunchOptionsKey.remoteNotification] == nil else {
			// we don't want to perfrom sync on launching when push received.
			return
		}
		mmContext?.sync()
	}
	
	func handleGeoServiceDidStartNotification() {
		mmContext?.currentInstallation?.syncSystemDataWithServer()
	}
	
	//MARK: Private
	weak private var mmContext: MobileMessaging?
}
