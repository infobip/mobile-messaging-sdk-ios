// 
//  Example/MobileMessagingExample/Utils/NSErrorExtension.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

public let CustomErrorDomain = "customDomain"

public enum CustomErrorType : Error {
	case invalidMSISDNFormat
	
	fileprivate var errorCode: Int {
		switch self {
		case .invalidMSISDNFormat:
			return 0
		}
	}
	
	var userInfo: [String: String] {
		var errorDescription: String = ""
		
		switch self {
		case .invalidMSISDNFormat:
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
