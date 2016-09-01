//
//  ManagedObjectNotificationCenter.swift
//
//  Created by Andrey K. on 09/06/16.
//
//

import Foundation
import CoreData

public typealias ObservationHandler = (_ keyPath: String, _ newValue: AnyObject) -> Void

//MARK: Observer
class ManagedObjectNotificationCenter {
	static let defaultCenter = ManagedObjectNotificationCenter()
	private var _observations = Set<Observation>()
	var observations: Set<Observation> {
		get {
			var res = Set<Observation>()
			observersQueue.executeSync {
				res = self._observations
			}
			return res
		}
	}
	private var observersQueue = MMQueue.Serial.newQueue(queueName: "com.mobile-messaging.queue.serial.mo-observer")
	
	deinit {
		removeAllObservers()
	}
	
	func removeAllObservers() {
		observersQueue.executeSync {
			for o in self._observations {
				o.stop()
			}
			self._observations.removeAll()
		}
	}
	
	func removeObserver(observer: NSObject, observee: NSManagedObject, forKeyPath keyPath: String) {
		self.removeObserver { (obs: Observation) -> Bool in
			return obs.observer == observer && obs.keyPath == keyPath && obs.observee == observee
		}
	}
	
	func removeObserver(observationId: String) {
		self.removeObserver {(obs: Observation) -> Bool in
			return obs.uniqueId == observationId
		}
	}
	
	func addObserver(observer: NSObject, observee: NSManagedObject, forKeyPath keyPath: String, handler: ObservationHandler) {
		observersQueue.executeSync {
			self.removeObserver(observer: observer, observee: observee, forKeyPath: keyPath)
			
			let newObs = Observation(observer: observer, observee: observee, keyPath: keyPath, handler: handler)
			newObs.start()
			newObs.onParticipantDeallocation { observation in
				self.removeObserver(observationId: observation.uniqueId)
			}
			self._observations.insert(newObs)
		}
	}
	
	private func removeObserver(filterBlock: @escaping (Observation) -> Bool) {
		observersQueue.executeSync {
			let ind = self._observations.index(where: filterBlock)
			if let ind = ind {
				let ob = self._observations[ind]
				ob.stop()
				self._observations.remove(at: ind)
			}
		}
	}
}

func address<T: AnyObject>(o: T) -> Int {
	return unsafeBitCast(o, to: Int.self)
}

//MARK: Observation
class Observation: NSObject {
	let uniqueId: String = NSUUID().uuidString
	var observer: NSObject?
	weak var observee: NSManagedObject?

	fileprivate let keyPath: String
	private let handler: ObservationHandler
	private var participantDeallocationHandler: ((Observation) -> Void)?
	func onParticipantDeallocation(block: @escaping (Observation) -> Void) {
		participantDeallocationHandler = block
	}
	private var changedValues = [String: AnyObject]()
	
	override func isEqual(_ object: Any?) -> Bool {
		if let object = object as? Observation {
			//TODO: take collisions into account(Equality of objects hash values doesn't mean that this objects are equal)
			return self.hash == object.hash
		}
		return false
	}
	
	override var hash: Int {
		guard let observer = observer, let observee = observee else {
			return 0
		}
		return address(o: observer) ^ address(o: observee) ^ keyPath.hashValue
	}
	
	init(observer: NSObject, observee: NSManagedObject, keyPath: String, handler: ObservationHandler) {
		self.observer = observer
		self.observee = observee
		self.keyPath = keyPath
		self.handler = handler
		super.init()
		
		self.observer?.onDeallocation {
			self.stop()
			self.participantDeallocationHandler?(self)
		}
		
		self.observee?.managedObjectContext?.performAndWait {
			self.observee?.onDeallocation {
				self.stop()
				self.participantDeallocationHandler?(self)
			}
			self.observee?.onTurninigIntoFault {
				self.stop()
				self.participantDeallocationHandler?(self)
			}
		}
	}
	
	func start() {
		if let ctx = observee?.managedObjectContext {
			NotificationCenter.default.addObserver(self, selector: #selector(Observation.objectsChanged(notification:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: ctx)
			NotificationCenter.default.addObserver(self, selector: #selector(Observation.contextDidSave(notification:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: ctx)
		}
	}
	
	fileprivate func stop() {
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
	}
	
	func contextDidSave(notification: NSNotification) {
		for (key, updatedValue) in changedValues where key == keyPath  {
			handler(keyPath, updatedValue)
		}
	}
	
	func objectsChanged(notification: NSNotification) {
		if let updatedObjects = notification.userInfo?["updated"] as? Set<NSManagedObject> {
			for obj in updatedObjects where obj == observee {
				changedValues = obj.changedValues() as [String : AnyObject]
			}
		}
	}
	
	deinit {
		stop()
	}
}

//MARK: NSManagedObject extension
extension NSManagedObject {
	// MARK: - Method Swizzling. The swizzling implemented in NSManagedObjectContext's initialize() otherwise not any NSManagedObject has a chance to get initialized. (crashing in runtime)
	func mobilemessaging_willTurnIntoFault() {
		self.mobilemessaging_willTurnIntoFault()
		for w in self.faultingWatchers() {
			w.block()
		}
	}
	
	func onTurninigIntoFault(block: @escaping (Void) -> Void) {
		var watchers = self.faultingWatchers()
		watchers.append(BlockObject(block: block))
		objc_setAssociatedObject(self, AssociatedKeys.AssociatedFaultingWatchersKey, watchers, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
	}
	
	func faultingWatchers() -> [BlockObject] {
		return (objc_getAssociatedObject(self, AssociatedKeys.AssociatedFaultingWatchersKey) as? [BlockObject]) ?? [BlockObject]()
	}
}

//MARK: NSObject extension
fileprivate extension NSObject {
	fileprivate struct AssociatedKeys {
		static var AssociatedDeallocationWatchersKey = "mm_AssociatedDeallocationWatchersKey"
		static var AssociatedFaultingWatchersKey = "mm_AssociatedFaultingWatchersKey"
	}
	
	func onDeallocation(block: @escaping (Void) -> Void) {
		var watchers = self.watchers()
		watchers.append(DeallocationWatcher(block: block))
		objc_setAssociatedObject(self, AssociatedKeys.AssociatedDeallocationWatchersKey, watchers, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
	}
	
	func watchers() -> [DeallocationWatcher] {
		return (objc_getAssociatedObject(self, AssociatedKeys.AssociatedDeallocationWatchersKey) as? [DeallocationWatcher]) ?? [DeallocationWatcher]()
	}
}

//MARK: Block wrapper
class BlockObject: NSObject {
	fileprivate var block: (Void) -> Void
	
	init(block: @escaping (Void) -> Void) {
		self.block = block
	}
}

//MARK: Deallocation watcher (will execute underlying block while on self deallocation)
class DeallocationWatcher: NSObject {
	private var block: (Void) -> Void
	
	init(block: @escaping (Void) -> Void) {
		self.block = block
	}
	
	deinit {
		block()
	}
}

//MARK: NSManagedObjectContext extension
extension NSManagedObjectContext {
	//	The swizzling for NSManagedObject implemented here, in NSManagedObjectContext's initialize(), otherwise not any NSManagedObject has a chance to get initialized. (crashing in runtime)
	override open class func initialize() {
		struct Static {
			static let swizzling : () = {
				let originalSelector = #selector(NSManagedObject.willTurnIntoFault)
				let swizzledSelector = #selector(NSManagedObject.mobilemessaging_willTurnIntoFault)
				
				let cl = NSManagedObject.self
				
				let originalMethod = class_getInstanceMethod(cl, originalSelector)
				let swizzledMethod = class_getInstanceMethod(cl, swizzledSelector)
				
				let didAddMethod = class_addMethod(cl, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
				
				if didAddMethod {
					class_replaceMethod(cl, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
				} else {
					method_exchangeImplementations(originalMethod, swizzledMethod)
				}
			}()
		}
		Static.swizzling
	}
}
