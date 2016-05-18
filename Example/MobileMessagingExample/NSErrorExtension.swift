//
//  Utils.swift
//  MobileMessaging
//
//  Created by okoroleva on 18.05.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation

public let CustomErrorDomain = "customDomain"

public enum CustomErrorType : ErrorType {
	case InvalidMSISDNFormat
	
	private var errorCode: Int {
		switch self {
		case .InvalidMSISDNFormat:
			return 0
		}
	}
	
	var userInfo: [String: String] {
		var errorDescription: String = ""
		
		switch self {
		case InvalidMSISDNFormat:
			errorDescription = NSLocalizedString("Invalid MSISDN format", comment: "")
		}
		return [NSLocalizedDescriptionKey: errorDescription]
	}
}

extension NSError {
	public convenience init(type: CustomErrorType) {
		self.init(domain: CustomErrorDomain, code: type.errorCode, userInfo: type.userInfo)
	}
}
