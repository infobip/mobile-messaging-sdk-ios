// 
//  NotPendingDepersonalizationCondition.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class NotPendingDepersonalizationCondition : OperationCondition {
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
		guard mmContext.internalData().currentDepersonalizationStatus != .pending else {
			operation.logWarn("Depersonalization is in pending state. Cancelling...")
			completion(OperationConditionResult.failed(NSError(type: MMInternalErrorType.ProtectedDataUnavailable)))
			return
		}
		completion(OperationConditionResult.satisfied)
	}
}
