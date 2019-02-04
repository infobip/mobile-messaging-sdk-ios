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
	static func remove(at path: String)
	func handleCurrentChanges(old: Self, new: Self)
}

extension ArchivableCurrent where Self: NSCopying {
	func archiveCurrent() {
		let old = Self.unarchiveCurrent()
		archive(at: Self.currentPath)
		handleCurrentChanges(old: old, new: self)
	}
	func archive(at path: String) {
		Self.cached.set(value: self.copy() as? Self, forKey: path)
		let save = self.copy() as! Self
		save.removeSensitiveData()
		NSKeyedArchiver.archiveRootObject(save, toFile: path)
	}
	static func resetCurrent() {
		Self.remove(at: Self.currentPath)
	}
	static func unarchiveCurrent() -> Self {
		return Self.unarchive(from: Self.currentPath) ?? Self.empty
	}
	static func unarchive(from path: String) -> Self? {
		if let cached = Self.cached.getValue(forKey: path) {
			return cached.copy() as? Self
		} else {
			let newVal = (NSKeyedUnarchiver.unarchiveObject(withFile: path) as? Self)
			Self.cached.set(value: newVal?.copy() as? Self, forKey: path)
			return newVal
		}
	}
	static func remove(at path: String) {
		Self.cached.set(value: nil, forKey: path)
		try? FileManager.default.removeItem(atPath: path)
	}
}

extension Archivable where Self: NSCopying {
	func archiveAll() {
		archiveCurrent()
		archiveDirty()
	}
	func archiveDirty() {
		if var copy = self.copy() as? Self {
			copy.version = version + 1
			let old = Self.unarchiveDirty()
			copy.archive(at: Self.dirtyPath)
			handleDirtyChanges(old: old, new: self)
		}
	}
	static func resetAll() {
		Self.resetDirty()
		Self.resetCurrent()
	}
	static func resetDirty() {
		Self.remove(at: Self.dirtyPath)
	}
	static func unarchiveDirty() -> Self {
		return Self.unarchive(from: Self.dirtyPath) ?? Self.unarchiveCurrent()
	}
	static func modifyAll(with block: (Self) -> Void) {
		let du = Self.unarchiveDirty()
		block(du)
		du.archiveDirty()

		let cu = Self.unarchiveCurrent()
		block(cu)
		cu.archiveCurrent()
	}
}
