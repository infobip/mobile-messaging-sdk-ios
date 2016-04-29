//
//  MMApplicationListener.swift
//  MobileMessaging
//
//  Created by Andrey K. on 24/02/16.
//  
//

import Foundation

class MMApplicationListener: NSObject {
	
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    init(messageHandler: MMMessageHandler, installation: MMInstallation) {
        self.messageHandler = messageHandler
        self.installation = installation
        super.init()
		
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleAppWillEnterForegroundNotification", name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleAppDidFinishLaunchingNotification", name: UIApplicationDidFinishLaunchingNotification, object: nil)
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
	
	private func resaveInstallation() {
		installation.syncWithServer()
	}
	
	private func syncWithServer() {
		messageHandler.syncWithServer()
	}
	
	private func triggerPeriodicalWork() {
		resaveInstallation()
		syncWithServer()
	}
}