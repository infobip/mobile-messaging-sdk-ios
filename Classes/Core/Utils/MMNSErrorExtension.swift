//
//  MMNSErrorExtension.swift
//  MobileMessaging
//
//  Created by okoroleva on 08.03.16.
//  

import Foundation

public let MMInternalErrorDomain = "com.mobile-messaging"


public enum MMInternalErrorType: Error {
    case UnknownError //TODO: check all occurences and replace with meaningful errors
	case NoRegistration
	case StorageInitializationError
    
    fileprivate var errorCode: Int {
        switch self {
        case .UnknownError:
            return 0
		case .NoRegistration:
			return 1
		case .StorageInitializationError:
			return 2
		}
    }

	var userInfo: [String: String] {
        var errorDescription: String = ""
        
        switch self {
        case .UnknownError:
            errorDescription = NSLocalizedString("Unknown error", comment: "")
		case .NoRegistration:
			if MobileMessaging.currentInstallation?.deviceToken != nil {
				errorDescription = NSLocalizedString("The application instance is not registered on the server yet. APNs device token was not received by the Mobile Messaging SDK. Make sure your app is set up correctly to work with remote notifications.", comment: "")
			} else {
				errorDescription = NSLocalizedString("The application instance is not registered on the server yet. The registration will be perfomed eventually. Subscribe to the notification `MMRegistrationUpdated` to be notified as the registration succeeded.", comment: "")
			}
		case .StorageInitializationError:
			errorDescription = NSLocalizedString("Core Data storage not initialized.", comment: "")
        }
        return [NSLocalizedDescriptionKey: errorDescription]
    }
}

extension NSError {
	public var mm_message: String? {
		return userInfo[APIKeys.kErrorText] as? String
	}
	
	public var mm_code: String? {
		return userInfo[APIKeys.kErrorMessageId] as? String
	}
	
	var mm_isRetryable: Bool {
		
		var retryableCodes = Set<Int>()
		
		for i in 404..<600 {
			retryableCodes.insert(i)
		}
		retryableCodes.insert(NSURLErrorUnknown)
		retryableCodes.insert(NSURLErrorCancelled)
		retryableCodes.insert(NSURLErrorTimedOut)
		retryableCodes.insert(NSURLErrorCannotFindHost)
		retryableCodes.insert(NSURLErrorCannotConnectToHost)
		retryableCodes.insert(NSURLErrorNetworkConnectionLost)
		retryableCodes.insert(NSURLErrorDNSLookupFailed)
		retryableCodes.insert(NSURLErrorResourceUnavailable)
		retryableCodes.insert(NSURLErrorNotConnectedToInternet)
		retryableCodes.insert(NSURLErrorBadServerResponse)
		retryableCodes.insert(NSURLErrorCannotDecodeRawData)
		retryableCodes.insert(NSURLErrorCannotDecodeContentData)
		retryableCodes.insert(NSURLErrorCannotParseResponse)
		
		return (domain == NSURLErrorDomain || domain == AFURLResponseSerializationErrorDomain) && retryableCodes.contains(code)
	}

    public convenience init(type: MMInternalErrorType) {
        self.init(domain: MMInternalErrorDomain, code: type.errorCode, userInfo: type.userInfo)
    }
}
