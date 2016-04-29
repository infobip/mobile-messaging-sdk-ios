//
//  RegistrationCondition.swift
//  Pods
//
//  Created by Andrey K. on 21/04/16.
//
//

import UIKit

class RegistrationCondition: OperationCondition {
	static var name = "RegistrationCondition"
	static var isMutuallyExclusive = false
	
	func dependencyForOperation(operation: Operation) -> NSOperation? {
		return nil
	}
	
	func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {
		if MobileMessaging.currentInstallation?.internalId == nil {
			completion(OperationConditionResult.Failed(NSError(type: MMInternalErrorType.NoRegistration)))
		} else {
			completion(OperationConditionResult.Satisfied)
		}
	}
}
