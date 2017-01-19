/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
This file defines the error codes and convenience functions for interacting with Operation-related errors.
*/

import Foundation

internal let OperationErrorDomain = "OperationErrors"

internal enum OperationErrorCode: Int {
	case conditionFailed = 1
	case executionFailed = 2
}

internal extension NSError {
	convenience init(code: OperationErrorCode, userInfo: [AnyHashable : Any]? = nil) {
		self.init(domain: OperationErrorDomain, code: code.rawValue, userInfo: userInfo)
	}
}

// This makes it easy to compare an `NSError.code` to an `OperationErrorCode`.
internal func ==(lhs: Int, rhs: OperationErrorCode) -> Bool {
	return lhs == rhs.rawValue
}

internal func ==(lhs: OperationErrorCode, rhs: Int) -> Bool {
	return lhs.rawValue == rhs
}
