//
//  ManagedObjectObserver.swift
//  Pods
//
//  Created by Andrey K. on 09/06/16.
//
//

import Foundation
import CoreData

public typealias ObservationHandler = (keyPath: String, newValue: AnyObject) -> Void

//MARK: Observer
class ManagedObjectObserver {
	static let sharedInstance = ManagedObjectObserver()
	private var observations = Set<Observation>()
	private var observersQueue = dispatch_queue_create("com.mobile-messaging.managedObjectObserverQueue",
	DISPATCH_QUEUE_SERIAL);
	
	deinit {
		removeAllObservers()
	}
	
	func removeAllObservers() {
		dispatch_sync(observersQueue) {
			self.observations.removeAll()
		}
	}
	
	func removeObserver(observer: NSObject, observee: NSManagedObject, forKeyPath keyPath: String) {
		dispatch_sync(observersQueue) {
			let ind = self.observations.indexOf { (obs: Observation) -> Bool in
				return obs.observer == observer && obs.keyPath == keyPath && obs.observee == observee
			}
			if let ind = ind {
				dispatch_barrier_async(self.observersQueue) {
					self.observations.removeAtIndex(ind)
				}
			}
		}
	}
	
	func addObserver(observer: NSObject, observee: NSManagedObject, forKeyPath keyPath: String, handler: ObservationHandler) {
		dispatch_sync(observersQueue) {
			let obs = Observation(observer: observer, observee: observee, keyPath: keyPath, handler: handler)
			obs.start()
			self.observations.insert(obs)
		}
	}
}

class Observation: NSObject {
	private weak var observer: NSObject?
	private weak var observee: NSManagedObject?
	private let keyPath: String
	private let handler: ObservationHandler
	private var changedValues = [String: AnyObject]()
	
	private func address<T: AnyObject>(o: T) -> Int {
		return unsafeBitCast(o, Int.self)
	}
	
	override func isEqual(object: AnyObject?) -> Bool {
		return hash == object?.hash
	}
	
	override var hash: Int {
		guard let observer = observer, let observee = observee else {
			stop()
			return 0
		}
		return address(observer) ^ address(observee) ^ keyPath.hashValue
	}
	
	init(observer: NSObject, observee: NSManagedObject, keyPath: String, handler: ObservationHandler) {
		self.observer = observer
		self.observee = observee
		self.keyPath = keyPath
		self.handler = handler
		super.init()
	}
	
	func start() {
		if let ctx = observee?.managedObjectContext {
			NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Observation.contextChanged(_:)), name: NSManagedObjectContextObjectsDidChangeNotification, object: ctx)
			NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Observation.contextDidSave(_:)), name: NSManagedObjectContextDidSaveNotification, object: ctx)
		}
	}
	
	private func stop() {
		NSNotificationCenter.defaultCenter().removeObserver(self, name: NSManagedObjectContextObjectsDidChangeNotification, object: nil)
		NSNotificationCenter.defaultCenter().removeObserver(self, name: NSManagedObjectContextDidSaveNotification, object: nil)
	}
	
	func contextDidSave(notification: NSNotification) {
		for (key, updatedValue) in changedValues where key == keyPath  {
			handler(keyPath: keyPath, newValue: updatedValue)
		}
	}
	
	func contextChanged(notification: NSNotification) {
		if let updatedObjects = notification.userInfo?["updated"] as? Set<NSManagedObject> {
			for obj in updatedObjects where obj == observee {
				changedValues = obj.changedValues()
			}
		}
	}
	
	deinit {
		stop()
	}
}