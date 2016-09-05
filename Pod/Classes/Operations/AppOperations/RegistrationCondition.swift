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
	let internalId: String?
	
	init(internalId: String?) {
		self.internalId = internalId
	}
	
	func dependencyForOperation(operation: Operation) -> NSOperation? {
		return nil
	}
	
	func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {
		if internalId == nil {
			completion(OperationConditionResult.Failed(NSError(type: MMInternalErrorType.NoRegistration)))
		} else {
			completion(OperationConditionResult.Satisfied)
		}
	}
}
