//
//  MMNSErrorExtension.swift
//  MobileMessaging
//
//  Created by okoroleva on 08.03.16.
//  

import Foundation

public let MMInternalErrorDomain = "com.mobile-messaging"

public enum MMInternalErrorType: Error {
    case UnknownError
	case NoRegistration
	case StorageInitializationError
	case PendingLogout
	case InvalidRegistration
	case CantLogoutCurrentRegistration
	case CantSetPrimaryCurrentRegistration
	case UnknownResponseFormat
	case MobileMessagingInstanceNotInitialized
	case ProtectedDataUnavailable
    
    fileprivate var errorCode: Int {
        switch self {
        case .UnknownError:
            return 0
		case .NoRegistration:
			return 1
		case .StorageInitializationError:
			return 2
		case .InvalidRegistration:
			return 3
		case .PendingLogout:
			return 4
		case .CantSetPrimaryCurrentRegistration:
			return 5
		case .CantLogoutCurrentRegistration:
			return 6
		case .UnknownResponseFormat:
			return 7
		case .MobileMessagingInstanceNotInitialized:
			return 8
		case .ProtectedDataUnavailable:
			return 9
		}
    }

	var userInfo: [String: String] {
        var errorDescription: String = ""
        
        switch self {
        case .UnknownError:
            errorDescription = NSLocalizedString("Unknown error", comment: "")
		case .NoRegistration:
			if MobileMessaging.sharedInstance?.resolveInstallation().pushServiceToken != nil {
				errorDescription = NSLocalizedString("The application instance is not registered on the server yet. APNs device token was not received by the Mobile Messaging SDK. Make sure your app is set up correctly to work with remote notifications.", comment: "")
			} else {
				errorDescription = NSLocalizedString("The application instance is not registered on the server yet. The registration will be perfomed eventually. Subscribe to the notification `MMNotificationRegistrationUpdated` to be notified as the registration succeeded.", comment: "")
			}
		case .StorageInitializationError:
			errorDescription = NSLocalizedString("Core Data storage not initialized.", comment: "")
		case .PendingLogout:
			errorDescription = NSLocalizedString("Logout operation is not finished yet. Certain server API calls are disabled.", comment: "")
		case .InvalidRegistration:
			errorDescription = NSLocalizedString("Registration is invalid. Current device token considered invalid due to reserve copy recovery. SDK will recover eventually.", comment: "")
		case .CantLogoutCurrentRegistration:
			errorDescription = NSLocalizedString("You are trying to depersonalize current installation with wrong API. Please use MobileMessaging.sharedInstance?.currentInstallation?.depersonalize(completion:) instead.", comment: "")
		case .CantSetPrimaryCurrentRegistration:
			errorDescription = NSLocalizedString("You are trying to set primary for current installation with wrong API. Please use MobileMessaging.sharedInstance?.currentInstallation?.save(isPrimaryDevice:completion:) instead.", comment: "")
		case .UnknownResponseFormat:
			errorDescription = NSLocalizedString("Unknown remote API response format, could not convert to a supported response type", comment: "")
		case .MobileMessagingInstanceNotInitialized:
			errorDescription = NSLocalizedString("Mobile Messaging instance not initialized. It's either you haven't started it or there were fatal errors due to initialization. Check Mobile Messaging logs for troubleshooting.", comment: "")
		case .ProtectedDataUnavailable:
			errorDescription = NSLocalizedString("Protected data is unavailable at this moment.", comment: "")
		}


        return [NSLocalizedDescriptionKey: errorDescription]
    }
	
	var foundationError: NSError {
		return NSError(type: self)
	}
}

extension Error {
	var mm_isNoSuchFile: Bool {
		return (self as NSError).mm_isNoSuchFile
	}
}

extension NSError {
	@objc public var mm_message: String? {
		return userInfo[Consts.APIKeys.errorText] as? String
	}
	
	@objc public var mm_code: String? {
		return userInfo[Consts.APIKeys.errorMessageId] as? String
	}
	
	var mm_isNoSuchFile: Bool {
		return domain == NSCocoaErrorDomain && (code == NSFileNoSuchFileError || code == NSFileReadNoSuchFileError)
	}
	
	var mm_isCannotFindHost: Bool {
		return domain == NSURLErrorDomain && code == NSURLErrorCannotFindHost
	}
	
    public convenience init(type: MMInternalErrorType) {
        self.init(domain: MMInternalErrorDomain, code: type.errorCode, userInfo: type.userInfo)
    }
}
