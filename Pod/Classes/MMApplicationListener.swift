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
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    init(messageHandler: MMMessageHandler, installation: MMInstallation) {
        self.messageHandler = messageHandler
        self.installation = installation
        super.init()
		
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MMApplicationListener.handleAppWillEnterForegroundNotification), name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MMApplicationListener.handleAppDidFinishLaunchingNotification), name: UIApplicationDidFinishLaunchingNotification, object: nil)
    }
	
	//MARK: Internal
	func handleAppWillEnterForegroundNotification() {
		if UIApplication.sharedApplication().isRemoteNotificationsEnabled {
			triggerPeriodicalWork()
		}
	}
	
	func handleAppDidFinishLaunchingNotification() {
		if UIApplication.sharedApplication().isRemoteNotificationsEnabled {
			messageHandler.evictOldMessages()
			triggerPeriodicalWork()
		}
	}
	
	//MARK: Private
	private var messageHandler: MMMessageHandler
	private var installation: MMInstallation
	
	private func triggerPeriodicalWork() {
		installation.syncWithServer()
		messageHandler.syncWithServer()
	}
}