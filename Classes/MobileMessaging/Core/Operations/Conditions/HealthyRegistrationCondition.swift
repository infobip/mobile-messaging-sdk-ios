//
//  HealthyRegistrationCondition.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 18.08.2020.
//

import Foundation

class HealthyRegistrationCondition : OperationCondition {
	static var name: String { get { return String(describing: self) } }
	
	let mmContext: MobileMessaging

	init(mmContext: MobileMessaging) {
		self.mmContext = mmContext
	}

	static var isMutuallyExclusive: Bool = false

	func dependencyForOperation(_ operation: Operation) -> Foundation.Operation? {
		return nil
	}

	func evaluateForOperation(_ operation: Operation, completion: @escaping (OperationConditionResult) -> Void) {
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			operation.logWarn("Registration is not healthy. Finishing...")
			completion(OperationConditionResult.failed(NSError(type: MMInternalErrorType.InvalidRegistration)))
			return
		}
		completion(OperationConditionResult.satisfied)
	}
}
