//
//  APIErrorHandler.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 26/04/2019.
//

import Foundation

class APIErrorHandler {
	static let sharedInstance = APIErrorHandler()

	func handleApiError(error: NSError?) {
		if error?.mm_code == "NO_REGISTRATION" {
			MobileMessaging.sharedInstance?.installationService.resetCurrentPushRegistration()
			MobileMessaging.sharedInstance?.userService.resyncUserData()
		}
	}
}
