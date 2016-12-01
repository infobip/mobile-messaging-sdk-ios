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
    
	init(messageHandler: MMMessageHandler, installation: MMInstallation, user: MMUser, geofencingService: MMGeofencingService) {
        self.messageHandler = messageHandler
        self.installation = installation
		self.user = user
		self.geofencingService = geofencingService
		
        super.init()
		
		NotificationCenter.default.addObserver(self, selector: #selector(MMApplicationListener.handleAppWillEnterForegroundNotification), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(MMApplicationListener.handleAppDidFinishLaunchingNotification), name: NSNotification.Name.UIApplicationDidFinishLaunching, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(MMApplicationListener.handleGeoServiceDidStartNotification), name: NSNotification.Name(rawValue: MMNotificationGeoServiceDidStart), object: nil)
		
    }
	
	//MARK: Internal
	func handleAppWillEnterForegroundNotification() {
		triggerPeriodicalWork()
	}
	
	func handleAppDidFinishLaunchingNotification() {
		messageHandler?.evictOldMessages()
		triggerPeriodicalWork()
	}
	
	func handleGeoServiceDidStartNotification() {
		installation?.syncSystemDataWithServer()
	}
	
	//MARK: Private
	weak private var messageHandler: MMMessageHandler?
	weak private var installation: MMInstallation?
	weak private var user: MMUser?
	weak private var geofencingService: MMGeofencingService?
	
	private func triggerPeriodicalWork() {
		installation?.syncInstallationWithServer()
		messageHandler?.syncWithServer()
		geofencingService?.syncWithServer()
	}
}
