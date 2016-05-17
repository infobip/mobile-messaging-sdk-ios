//
//  MMNSErrorExtension.swift
//  MobileMessaging
//
//  Created by Ольга Королева on 08.03.16.
//  
//
import Foundation

public let MMInternalErrorDomain = "com.mobile-messaging"

public enum MMInternalErrorType : ErrorType {
    case UnknownError
    case OperationCanceled
	case NoRegistration
	case StorageInitializationError
	case EmptyMsisdn
    
    private var errorCode: Int {
        switch self {
        case .UnknownError:
            return 0
        case .OperationCanceled:
            return 1
		case .NoRegistration:
			return 2
		case .StorageInitializationError:
			return 3
		case .EmptyMsisdn:
			return 4
        }
    }

	var userInfo: [String: String] {
        var errorDescription: String = ""
        
        switch self {
        case UnknownError:
            errorDescription = NSLocalizedString("Unknown error", comment: "")
        case OperationCanceled:
            errorDescription = NSLocalizedString("Task cancelled internally", comment: "")
		case NoRegistration:
			if MobileMessaging.currentInstallation?.deviceToken != nil {
				errorDescription = NSLocalizedString("The application instance is not registered on the server yet. APNs device token was not received by the Mobile Messaging SDK. Make sure your app is set up correctly to work with remote notifications.", comment: "")
			} else {
				errorDescription = NSLocalizedString("The application instance is not registered on the server yet. The registration will be perfomed eventually. Subscribe to the notification `MMEventNotifications.kRegistrationUpdated` to be notified as the registration succeeded.", comment: "")
			}
		case StorageInitializationError:
			errorDescription = NSLocalizedString("Core Data storage not initialized.", comment: "")
		case .EmptyMsisdn:
			errorDescription = NSLocalizedString("MSISDN is Empty.", comment: "")
        }
        return [NSLocalizedDescriptionKey: errorDescription]
    }
}

extension NSError {
	var mm_isRetryable: Bool {
		return mm_isNetworkingError
	}

    public convenience init(type: MMInternalErrorType) {
        self.init(domain: MMInternalErrorDomain, code: type.errorCode, userInfo: type.userInfo)
    }
	
	var mm_isCancelledOperationError: Bool {
		return domain == MMInternalErrorDomain && code == MMInternalErrorType.OperationCanceled.errorCode
	}
	
    var mm_isNetworkingError: Bool {
        return (code >= 404 || code < -998) && domain == NSURLErrorDomain
    }
}
