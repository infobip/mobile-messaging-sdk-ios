//
//  Archivable.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 04/02/2019.
//

import Foundation
import CoreLocation

public protocol Archivable: ArchivableCurrent {
	var version: Int {get set}
	static var dirtyPath: String {get}
	func archiveAll()
	func archiveDirty()
	static func resetAll()
	static func resetDirty()
	static func unarchiveDirty() -> Self
	func handleDirtyChanges(old: Self, new: Self)
	static func modifyAll(with block: (Self) -> Void)
	static func modifyDirty(with block: (Self) -> Void)
}

public protocol ArchivableCurrent: NSObject {
	static var empty: Self {get}
	static var cached: ThreadSafeDict<Self> {get}
	static var currentPath: String {get}
	func archiveCurrent()
	static func unarchive(from path: String) -> Self?
	func archive(at path: String)
	func removeSensitiveData()
	static func resetCurrent()
	static func unarchiveCurrent() -> Self
	static func removeArchive(at path: String)
	func handleCurrentChanges(old: Self, new: Self)
	static func modifyCurrent(with block: (Self) -> Void)
}

extension ArchivableCurrent where Self: NSCopying, Self: NSCoding {
    public func archiveCurrent() {
		let old = Self.unarchiveCurrent()
        MMLogVerbose("Setting cached value \(Thread.current.description) \(Self.currentPath)")
		Self.cached.set(value: self.copy() as? Self, forKey: Self.currentPath)
		archive(at: Self.currentPath)
		handleCurrentChanges(old: old, new: self)
	}
    public func archive(at path: String) {
        MMLogVerbose("Archiving \(Thread.current.description) at \(path)")
		let save = self.copy() as! Self
		save.removeSensitiveData()
        do {
            let dataToBeArchived = try NSKeyedArchiver.archivedData(withRootObject: save, requiringSecureCoding: true)
            try dataToBeArchived.write(to: URL(fileURLWithPath: path))
        } catch {
            MMLogError("Unexpected error while archiving at \(path): \(error)")
        }
	}
    public static func resetCurrent() {
        MMLogVerbose("Resetting cached value \(Thread.current.description) \(Self.currentPath)")
		Self.cached.set(value: nil, forKey: Self.currentPath)
		Self.removeArchive(at: Self.currentPath)
	}
    public static func unarchiveCurrent() -> Self {
		if let cached = Self.cached.getValue(forKey: Self.currentPath), let ret = cached.copy() as? Self {
            MMLogVerbose("Using cached value \(Thread.current.description) \(Self.currentPath)")
			return ret
		} else {
			let current = Self.unarchive(from: Self.currentPath) ?? Self.empty
            MMLogVerbose("Setting cached value \(Thread.current.description) \(current) \(Self.currentPath)")
			Self.cached.set(value: current.copy() as? Self, forKey: Self.currentPath)
			return current
		}
	}
    public static func unarchive(from path: String) -> Self? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        do {
            let unarchived = try NSKeyedUnarchiver.unarchivedObject(ofClass: Self.self, from: data)
            MMLogVerbose("Unarchived \(String(describing: unarchived)) from \(path)")
            return unarchived
        } catch {
            MMLogError("Unable to unarchive object with error: \(error)")
        }
        return nil
    }
    public static func removeArchive(at path: String) {
		MMLogVerbose("Removing archive \(Thread.current.description) at \(path)")
		do {
			try FileManager.default.removeItem(atPath: path)
		} catch {
			MMLogError("Unexpected error while removing archive at \(path): \(error)")
		}
	}
    public static func modifyCurrent(with block: (Self) -> Void) {
		let o = Self.unarchiveCurrent()
		block(o)
		o.archiveCurrent()
	}
}

extension Archivable where Self: NSCopying {
    public func archiveAll() {
		archiveDirty()
		archiveCurrent()
	}
    public func archiveDirty() {
        if var copy = self.copy() as? Self {
			copy.version = version + 1
			let old = Self.unarchiveDirty()
            MMLogVerbose("Setting cached value \(Thread.current.description) \(self) \(Self.dirtyPath)")
			Self.cached.set(value: self.copy() as? Self, forKey: Self.dirtyPath)
			copy.archive(at: Self.dirtyPath)
			handleDirtyChanges(old: old, new: self)
		}
	}
    public static func resetAll() {
		Self.resetDirty()
		Self.resetCurrent()
	}
    public static func resetDirty() {
        MMLogVerbose("Resetting dirty \(Thread.current.description) \(Self.dirtyPath)")
		Self.cached.set(value: nil, forKey: Self.dirtyPath)
		Self.removeArchive(at: Self.dirtyPath)
	}
    public static func unarchiveDirty() -> Self {
		if let cached = Self.cached.getValue(forKey: Self.dirtyPath), let ret = cached.copy() as? Self {
            MMLogVerbose("Using cached value \(Thread.current.description) \(Self.dirtyPath)")
			return ret
		} else {
			let dirty = Self.unarchive(from: Self.dirtyPath) ?? Self.unarchiveCurrent()
            MMLogVerbose("Setting cached value \(Thread.current.description) \(dirty) \(Self.dirtyPath)")
			Self.cached.set(value: dirty.copy() as? Self, forKey: Self.dirtyPath)
			return dirty
		}
	}
    public static func modifyAll(with block: (Self) -> Void) {
		Self.modifyDirty(with: block)
		Self.modifyCurrent(with: block)
	}
    public static func modifyDirty(with block: (Self) -> Void) {
		let du = Self.unarchiveDirty()
		block(du)
		du.archiveDirty()
	}
}
