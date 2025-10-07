// 
//  HealthyRegistrationCondition.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

public class HealthyRegistrationCondition : OperationCondition {
    public static var name: String { get { return String(describing: self) } }
	
	let mmContext: MobileMessaging

    public init(mmContext: MobileMessaging) {
		self.mmContext = mmContext
	}

    public static var isMutuallyExclusive: Bool = false

    public func dependencyForOperation(_ operation: Operation) -> Foundation.Operation? {
		return nil
	}

    public func evaluateForOperation(_ operation: Operation, completion: @escaping (OperationConditionResult) -> Void) {

		guard mmContext.apnsRegistrationManager != nil && mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			operation.logWarn("Registration is not healthy. Finishing...")
			completion(OperationConditionResult.failed(NSError(type: MMInternalErrorType.InvalidRegistration)))
			return
		}
		completion(OperationConditionResult.satisfied)
	}
}
