//
//  RegistrationCondition.swift
//
//  Created by Andrey K. on 21/04/16.
//
//

import UIKit

final class RegistrationCondition: OperationCondition {
	static var name = "RegistrationCondition"
	static var isMutuallyExclusive = false
	
	public func dependencyForOperation(_ operation: Operation) -> Foundation.Operation? {
		return nil
	}
	
	public func evaluateForOperation(_ operation: Operation, completion: @escaping (OperationConditionResult) -> Void) {
		if MobileMessaging.currentUser?.internalId == nil {
			completion(OperationConditionResult.failed(NSError(type: MMInternalErrorType.NoRegistration)))
		} else {
			completion(OperationConditionResult.satisfied)
		}
	}
}
