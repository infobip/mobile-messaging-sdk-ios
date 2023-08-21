//
//  MMGCD.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//  
//

import Foundation

final public class MMQueueObject: CustomStringConvertible {
    
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
	
	public func async(closure: @escaping () -> Void) {
        if isCurrentQueue {
            closure()
        } else {
            queue.async(execute: closure)
        }
    }
    
    func asyncBarier(closure: @escaping () -> Void) {
        if isCurrentQueue {
            closure()
        } else {
			queue.async(flags: .barrier) {
				closure()
			}
        }
    }

    public func sync(closure: () -> Void) {
        if isCurrentQueue {
            closure()
        } else {
            queue.sync(execute: closure)
        }
    }
	
	func getSync<T>(closure: () -> T) -> T {
		if isCurrentQueue {
			return closure()
		} else {
			var ret: T!
			queue.sync(execute: {
				ret = closure()
			})
			return ret!
		}
	}
	
    public var description: String { return queue.label }
}

protocol MMQueueEnum {
	var queue: MMQueueObject {get}
	var queueName: String {get}
}

public enum MMQueue {
	case Main
	case Global
	public var queue: MMQueueObject {
		switch self {
		case .Global:
			return MMQueueObject(queue: DispatchQueue.global(qos: .default))
		case .Main:
			return MMQueueObject(queue: DispatchQueue.main)
		}
		
	}
	
	enum Serial {
		enum New: String, MMQueueEnum {
			case MessageStorageQueue = "com.mobile-messaging.queue.serial.message-storage"
			case UserSessionQueue = "com.mobile-messaging.queue.serial.user-session"
			case PostponerQueue = "com.mobile-messaging.queue.serial.postponer"
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

func getFromMain<T>(getter: () -> T) -> T {
	return MMQueue.Main.queue.getSync(closure: { getter() })
}

func inMainWait(block: () -> Void) {
	return MMQueue.Main.queue.sync(closure: block)
}

func inMain(block: @escaping () -> Void) {
	return MMQueue.Main.queue.async(closure: block)
}

