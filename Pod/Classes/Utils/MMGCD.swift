//
//  MMGCD.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//  
//

import Foundation

func synced(lock: AnyObject, closure: Void -> Void) {
	objc_sync_enter(lock)
	closure()
	objc_sync_exit(lock)
}

final class MMQueueObject: CustomStringConvertible {
    
    private(set) var queue: dispatch_queue_t

	private var queueTag: UnsafeMutablePointer<Void>
	
    var isCurrentQueue: Bool {
		if isMain {
			return NSThread.isMainThread()
		} else if isGlobal {
			return queueLabel == String(UTF8String: dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL))
		}
		return dispatch_get_specific(queueTag) != nil
	}
    
    deinit { queueTag.dealloc(1) }
	
	init(queue: dispatch_queue_t) {
		self.queue = queue
		let charPtr = dispatch_queue_get_label(queue)
		self.queueLabel = String(UTF8String: charPtr)
		self.queueTag = UnsafeMutablePointer.alloc(1)
		dispatch_queue_set_specific(queue, queueTag, queueTag, nil)
	}
	
	var isGlobal: Bool {
		return queueLabel?.hasPrefix("com.apple.root.") ?? false
	}
	
	var isMain: Bool {
		return queueLabel == "com.apple.main-thread"
	}
	
	var queueLabel: String?
	
    func executeAsync(closure: Void -> Void) {
        if isCurrentQueue {
            closure()
        } else {
            dispatch_async(queue, closure)
        }
    }
    
    func executeAsyncBarier(closure: Void -> Void) {
        if isCurrentQueue {
            closure()
        } else {
            dispatch_barrier_async(queue, closure)
        }
    }

    func executeSync(closure: Void -> Void) {
        if isCurrentQueue {
            closure()
        } else {
            dispatch_sync(queue, closure)
        }
    }
	
	var description: String { return String(UTF8String: dispatch_queue_get_label(queue)) ?? "untitled queue" }
}

protocol MMQueueEnum {
	var queue: MMQueueObject {get}
	var queueName: String {get}
}

final class MMQueuePool {
	class func queue(queueEnum: MMQueueEnum, queueBuilder: Void -> MMQueueObject) -> MMQueueObject {
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
			return MMQueueObject(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
		case .Main:
			return MMQueueObject(queue: dispatch_get_main_queue())
		}
		
	}
	
	enum Serial {
		enum Reusable: String, MMQueueEnum {
			case DefaultQueue = "com.mobile-messaging.queue.serial.default-shared"
			var queueName: String { return rawValue }
			var queue: MMQueueObject {
				return MMQueuePool.queue(self, queueBuilder: { Serial.newQueue(self.queueName) })
			}
		}
		
		enum New: String, MMQueueEnum {
			case MobileMessagingSingletonQueue = "com.mobile-messaging.queue.serial.api-singleton"
			case RetryableRequest = "com.mobile-messaging.queue.serial.request-retry"
			var queueName: String { return rawValue }
			var queue: MMQueueObject { return Serial.newQueue(queueName) }
		}
		
		static func newQueue(queueName: String) -> MMQueueObject {
			return MMQueueObject(queue: dispatch_queue_create(queueName, DISPATCH_QUEUE_SERIAL))
		}
	}
	
	enum Concurrent {
		static func newQueue(queueName: String) -> MMQueueObject {
			return MMQueueObject(queue: dispatch_queue_create(queueName, DISPATCH_QUEUE_CONCURRENT))
		}
	}
}