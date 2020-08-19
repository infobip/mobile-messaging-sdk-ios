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

	override func mobileMessagingWillStart(_ mmContext: MobileMessaging) {
		start({ _ in})
	}

	override func mobileMessagingWillStop(_ mmContext: MobileMessaging) {
		stop({ _ in})
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
	@objc func handleAppWillEnterForegroundNotification(_ n: Notification) {
		mmContext.performForEachSubservice { (s) in
			s.appWillEnterForeground(n)
		}
	}
	
	@objc func handleAppDidFinishLaunchingNotification(_ n: Notification) {
		guard n.userInfo?[UIApplication.LaunchOptionsKey.remoteNotification] == nil else {
			// we don't want to work on launching when push received.
			return
		}
		mmContext.performForEachSubservice { (s) in
			s.appDidFinishLaunching(n)
		}
	}
	
	@objc func handleGeoServiceDidStartNotification(_ n: Notification) {
		mmContext.performForEachSubservice { (s) in
			s.geoServiceDidStart(n)
		}
	}

	@objc private func handleDidBecomeActive(_ n: Notification) {
		mmContext.performForEachSubservice { (s) in
			s.appDidBecomeActive(n)
		}
	}

	@objc private func handleAppWillResignActive(_ n: Notification) {
		mmContext.performForEachSubservice { (s) in
			s.appWillResignActive(n)
		}
	}

	@objc private func handleAppWillTerminate(_ n: Notification) {
		mmContext.performForEachSubservice { (s) in
			s.appWillTerminate(n)
		}
	}

	@objc private func handleAppDidEnterBackground(_ n: Notification) {
		mmContext.performForEachSubservice { (s) in
			s.appDidEnterBackground(n)
		}
	}

	
	//MARK: Private
	private func setupObservers() {
		guard !isTestingProcessRunning else {
			return
		}
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleAppWillResignActive(_:)),
			name: UIApplication.willResignActiveNotification, object: nil)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleDidBecomeActive(_:)),
			name: UIApplication.didBecomeActiveNotification, object: nil)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleAppWillTerminate(_:)),
			name: UIApplication.willTerminateNotification, object: nil)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleAppDidEnterBackground(_:)),
			name: UIApplication.didEnterBackgroundNotification, object: nil)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleAppWillEnterForegroundNotification(_:)),
			name: UIApplication.willEnterForegroundNotification, object: nil)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleAppDidFinishLaunchingNotification(_:)),
			name: UIApplication.didFinishLaunchingNotification, object: nil)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleGeoServiceDidStartNotification(_:)),
			name: NSNotification.Name(rawValue: MMNotificationGeoServiceDidStart), object: nil)
	}
}
