//
//  MMApplicationListener.swift
//  MobileMessaging
//
//  Created by Andrey K. on 24/02/16.
//  
//

import Foundation

final class MMApplicationListener: MobileMessagingService {
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
	init(mmContext: MobileMessaging) {
        super.init(mmContext: mmContext, id: "MMApplicationListener")
    }

	override func start(_ completion: @escaping (Bool) -> Void) {
		setupObservers()
		super.start(completion)
	}

	override func stop(_ completion: @escaping (Bool) -> Void) {
		NotificationCenter.default.removeObserver(self)
		super.stop({ _ in })
	}
	
	//MARK: Internal
	@objc func handleAppWillEnterForegroundNotification() {
		performPeriodicWork()
	}
	
	@objc func handleAppDidFinishLaunchingNotification(n: Notification) {
		guard n.userInfo?[UIApplication.LaunchOptionsKey.remoteNotification] == nil else {
			// we don't want to perfrom sync on launching when push received.
			return
		}
		performPeriodicWork()
	}
	
	@objc func handleGeoServiceDidStartNotification() {
		mmContext.installationService?.syncSystemDataWithServer() { _ in }
	}
	
	//MARK: Private

	private func performPeriodicWork() {
		mmContext.sync()
		if mmContext.internalData().currentDepersonalizationStatus == .pending {
			mmContext.installationService.depersonalize(completion: { _, _ in })
		}
	}

	private func setupObservers() {
		guard !isTestingProcessRunning else {
			return
		}
		NotificationCenter.default.addObserver(self,
											   selector: #selector(MMApplicationListener.handleAppWillEnterForegroundNotification),
											   name: UIApplication.willEnterForegroundNotification, object: nil)

		NotificationCenter.default.addObserver(self,
											   selector: #selector(MMApplicationListener.handleAppDidFinishLaunchingNotification(n:)),
											   name: UIApplication.didFinishLaunchingNotification, object: nil)

		NotificationCenter.default.addObserver(self,
											   selector: #selector(MMApplicationListener.handleGeoServiceDidStartNotification),
											   name: NSNotification.Name(rawValue: MMNotificationGeoServiceDidStart), object: nil)
	}
}
