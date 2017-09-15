//
//  MMGCD.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//  
//

import Foundation

func synced(lock: AnyObject, closure: () -> Void) {
	objc_sync_enter(lock)
	closure()
	objc_sync_exit(lock)
}

final class MMQueueObject: CustomStringConvertible {
    
    private(set) var queue: DispatchQueue

	private var queueTag: DispatchSpecificKey<String>
	
    var isCurrentQueue: Bool {
		if isMain {
			return Thread.isMainThread
		} else if isGlobal {
			return DispatchQueue.getSpecific(key: queueTag) == DispatchQueue.global().label
		}
		return DispatchQueue.getSpecific(key: queueTag) != nil
	}
	
	init(queue: DispatchQueue) {
		self.queue = queue
		self.queueLabel = queue.label
		self.queueTag = DispatchSpecificKey<String>()
		queue.setSpecific(key: queueTag, value: queue.label)
	}
	
	var isGlobal: Bool {
		return queueLabel?.hasPrefix("com.apple.root.") ?? false
	}
	
	var isMain: Bool {
		return queueLabel == "com.apple.main-thread"
	}
	
	var queueLabel: String?
	
	func executeAsync(closure: @escaping () -> Void) {
        if isCurrentQueue {
            closure()
        } else {
            queue.async(execute: closure)
        }
    }
    
    func executeAsyncBarier(closure: @escaping () -> Void) {
        if isCurrentQueue {
            closure()
        } else {
			queue.async(flags: .barrier) {
				closure()
			}
        }
    }

    func executeSync(closure: () -> Void) {
        if isCurrentQueue {
            closure()
        } else {
            queue.sync(execute: closure)
        }
    }
	
	var description: String { return queue.label }
}

protocol MMQueueEnum {
	var queue: MMQueueObject {get}
	var queueName: String {get}
}

final class MMQueuePool {
	class func queue(queueEnum: MMQueueEnum, queueBuilder: () -> MMQueueObject) -> MMQueueObject {
		var queue: MMQueueObject
		objc_sync_enter(qTable)
		if let q = qTable[queueEnum.queueName] {
			queue = q
		} else {
			let q = queueBuilder()
			qTable[queueEnum.queueName] = q
			queue = q
		}
		objc_sync_exit(qTable)
		return queue
	}
	
	private static var qTable = [String: MMQueueObject]()
}

enum MMQueue {
	case Main
	case Global
	var queue: MMQueueObject {
		switch self {
		case .Global:
			return MMQueueObject(queue: DispatchQueue.global(qos: .default))
		case .Main:
			return MMQueueObject(queue: DispatchQueue.main)
		}
		
	}
	
	enum Serial {
		enum Reusable: String, MMQueueEnum {
			case MessageStorageQueue = "com.mobile-messaging.queue.serial.message-storage"
			case DefaultQueue = "com.mobile-messaging.queue.serial.default-shared"
			var queueName: String { return rawValue }
			var queue: MMQueueObject {
				return MMQueuePool.queue(queueEnum: self, queueBuilder: { Serial.newQueue(queueName: self.queueName) })
			}
		}
		
		enum New: String, MMQueueEnum {
			case RetryableRequest = "com.mobile-messaging.queue.serial.request-retry"
			var queueName: String { return rawValue }
			var queue: MMQueueObject { return Serial.newQueue(queueName: queueName) }
		}
		
		static func newQueue(queueName: String) -> MMQueueObject {
			return MMQueueObject(queue: DispatchQueue(label: queueName))
		}
	}
	
	enum Concurrent {
		static func newQueue(queueName: String) -> MMQueueObject {
			return MMQueueObject(queue: DispatchQueue(label: queueName, attributes: DispatchQueue.Attributes.concurrent))
		}
	}
}
