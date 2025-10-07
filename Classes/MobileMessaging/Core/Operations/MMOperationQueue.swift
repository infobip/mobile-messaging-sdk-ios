// 
//  MMOperationQueue.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import UIKit

public class MMOperationQueue: OperationQueue, NamedLogger {
	public func addOperationExclusively(_ operation: Foundation.Operation) -> Bool {
        guard operations.contains(where: { type(of: $0) == type(of: operation) && ($0.isFinished || $0.isCancelled) }) == false else
		{
			logDebug("\(type(of: operation)) was not queued because a queue is already taken with the same kind of operation.")
			return false
		}
		addOperation(operation)
		return true
	}
	
	public override init() {
		super.init()
		self.name = self.queueName
	}
	
    init(name: String) {
        super.init()
        self.name = name
    }
    
	var queueName: String {
		return "com.mobile-messaging.default-queue"
	}

    public static func newSerialQueue(underlyingQueue: DispatchQueue?, name: String) -> MMOperationQueue {
		let newQ = MMOperationQueue()
		newQ.maxConcurrentOperationCount = 1
        newQ.underlyingQueue = underlyingQueue
        newQ.name = name
		return newQ
	}
	
    static func userInitiatedQueue(underlyingQueue: DispatchQueue?, name: String) -> MMOperationQueue {
		let newQ = MMOperationQueue()
		newQ.qualityOfService = .userInitiated
		newQ.maxConcurrentOperationCount = 1
        newQ.underlyingQueue = underlyingQueue
        newQ.name = name
		return newQ
	}
}
