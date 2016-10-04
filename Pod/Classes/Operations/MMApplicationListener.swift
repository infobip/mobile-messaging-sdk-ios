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
    
	init(messageHandler: MMMessageHandler, installation: MMInstallation, user: MMUser) {
        self.messageHandler = messageHandler
        self.installation = installation
		self.user = user
		
        super.init()
		
        NotificationCenter.default.addObserver(self, selector: #selector(MMApplicationListener.handleAppWillEnterForegroundNotification), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(MMApplicationListener.handleAppDidFinishLaunchingNotification), name: NSNotification.Name.UIApplicationDidFinishLaunching, object: nil)
    }
	
	//MARK: Internal
	func handleAppWillEnterForegroundNotification() {
		triggerPeriodicalWork()
	}
	
	func handleAppDidFinishLaunchingNotification() {
		messageHandler.evictOldMessages()
		triggerPeriodicalWork()
	}
	
	//MARK: Private
	private var messageHandler: MMMessageHandler
	private var installation: MMInstallation
	private var user: MMUser
	
	private func triggerPeriodicalWork() {
		installation.syncWithServer()
		user.syncWithServer()
		messageHandler.syncWithServer()
	}
}