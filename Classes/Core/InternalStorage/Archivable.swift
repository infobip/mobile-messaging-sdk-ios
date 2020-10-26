//
//  Archivable.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 04/02/2019.
//

import Foundation

protocol Archivable: ArchivableCurrent {
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

protocol ArchivableCurrent {
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

extension ArchivableCurrent where Self: NSCopying {
	func archiveCurrent() {
		let old = Self.unarchiveCurrent()
		Self.cached.set(value: self.copy() as? Self, forKey: Self.currentPath)
		archive(at: Self.currentPath)
		handleCurrentChanges(old: old, new: self)
	}
	func archive(at path: String) {
		MMLogVerbose("Archiving \(self) at \(path)")
		let save = self.copy() as! Self
		save.removeSensitiveData()
		NSKeyedArchiver.archiveRootObject(save, toFile: path)
	}
	static func resetCurrent() {
		Self.cached.set(value: nil, forKey: Self.currentPath)
		Self.removeArchive(at: Self.currentPath)
	}
	static func unarchiveCurrent() -> Self {
		if let cached = Self.cached.getValue(forKey: Self.currentPath), let ret = cached.copy() as? Self {
			return ret
		} else {
			let current = Self.unarchive(from: Self.currentPath) ?? Self.empty
			Self.cached.set(value: current.copy() as? Self, forKey: Self.currentPath)
			return current
		}
	}
	static func unarchive(from path: String) -> Self? {
		let unarchived = NSKeyedUnarchiver.unarchiveObject(withFile: path) as? Self
		MMLogVerbose("Unarchived \(String(describing: unarchived)) from \(path)")
		return unarchived
	}
	static func removeArchive(at path: String) {
		MMLogVerbose("Removing archive at \(path)")
		do {
			try FileManager.default.removeItem(atPath: path)
		} catch {
			MMLogError("Unexpected error while removing archive at \(path): \(error)")
		}
	}
	static func modifyCurrent(with block: (Self) -> Void) {
		let o = Self.unarchiveCurrent()
		block(o)
		o.archiveCurrent()
	}
}

extension Archivable where Self: NSCopying {
	func archiveAll() {
		archiveDirty()
		archiveCurrent()
	}
	func archiveDirty() {
		if var copy = self.copy() as? Self {
			copy.version = version + 1
			let old = Self.unarchiveDirty()
			Self.cached.set(value: self.copy() as? Self, forKey: Self.dirtyPath)
			copy.archive(at: Self.dirtyPath)
			handleDirtyChanges(old: old, new: self)
		}
	}
	static func resetAll() {
		Self.resetDirty()
		Self.resetCurrent()
	}
	static func resetDirty() {
		Self.cached.set(value: nil, forKey: Self.dirtyPath)
		Self.removeArchive(at: Self.dirtyPath)
	}
	static func unarchiveDirty() -> Self {
		if let cached = Self.cached.getValue(forKey: Self.dirtyPath), let ret = cached.copy() as? Self {
			return ret
		} else {
			let dirty = Self.unarchive(from: Self.dirtyPath) ?? Self.unarchiveCurrent()
			Self.cached.set(value: dirty.copy() as? Self, forKey: Self.dirtyPath)
			return dirty
		}
	}
	static func modifyAll(with block: (Self) -> Void) {
		Self.modifyDirty(with: block)
		Self.modifyCurrent(with: block)
	}
	static func modifyDirty(with block: (Self) -> Void) {
		let du = Self.unarchiveDirty()
		block(du)
		du.archiveDirty()
	}
}
