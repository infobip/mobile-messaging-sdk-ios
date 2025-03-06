//
// KeychainSwift.swift
//
// The MIT License
//
// Copyright (c) 2015 - 2024 Evgenii Neumerzhitckii
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Security
import Foundation

/**

A collection of helper functions for saving text and data in the keychain.

*/
class KeychainSwift {
	
	var lastQueryParameters: [String: Any]? // Used by the unit tests
	
	/// Contains result code from the last operation. Value is noErr (0) for a successful result.
	var lastResultCode: OSStatus = noErr
	
	var keyPrefix = "" // Can be useful in test.
	
	/**
	
	Specify an access group that will be used to access keychain items. Access groups can be used to share keychain items between applications. When access group value is nil all application access groups are being accessed. Access group name is used by all functions: set, get, delete and clear.
	
	*/
	var accessGroup: String?
	
	
	/**
	
	Specifies whether the items can be synchronized with other devices through iCloud. Setting this property to true will
	add the item to other devices with the `set` method and obtain synchronizable items with the `get` command. Deleting synchronizable items will remove them from all devices. In order for keychain synchronization to work the user must enable "Keychain" in iCloud settings.
	
	Does not work on macOS.
	
	*/
	var synchronizable: Bool = false
	
	/// Instantiate a KeychainSwift object
	init() { }
	
	/**
	
	- parameter keyPrefix: a prefix that is added before the key in get/set methods. Note that `clear` method still clears everything from the Keychain.
	
	*/
	init(keyPrefix: String) {
		self.keyPrefix = keyPrefix
	}
	
	/**
	
	Stores the text value in the keychain item under the given key.
	
	- parameter key: Key under which the text value is stored in the keychain.
	- parameter value: Text string to be written to the keychain.
	- parameter withAccess: Value that indicates when your app needs access to the text in the keychain item. By default the .AccessibleWhenUnlocked option is used that permits the data to be accessed only while the device is unlocked by the user.
	
	- returns: True if the text was successfully written to the keychain.
	
	*/
	@discardableResult
	func set(_ value: String, forKey key: String,
	         withAccess access: KeychainSwiftAccessOptions? = nil) -> Bool {
		
		if let value = value.data(using: String.Encoding.utf8) {
			return set(value, forKey: key, withAccess: access)
		}
		
		return false
	}
	
	/**
	
	Stores the data in the keychain item under the given key.
	
	- parameter key: Key under which the data is stored in the keychain.
	- parameter value: Data to be written to the keychain.
	- parameter withAccess: Value that indicates when your app needs access to the text in the keychain item. By default the .AccessibleWhenUnlocked option is used that permits the data to be accessed only while the device is unlocked by the user.
	
	- returns: True if the text was successfully written to the keychain.
	
	*/
	@discardableResult
	func set(_ value: Data, forKey key: String,
	         withAccess access: KeychainSwiftAccessOptions? = nil) -> Bool {
		
		delete(key) // Delete any existing key before saving it
		
		let accessible = access?.value ?? KeychainSwiftAccessOptions.defaultOption.value
		
		let prefixedKey = keyWithPrefix(key)
		
		var query: [String : Any] = [
			KeychainSwiftConstants.klass       : kSecClassGenericPassword,
			KeychainSwiftConstants.attrAccount : prefixedKey,
			KeychainSwiftConstants.valueData   : value,
			KeychainSwiftConstants.accessible  : accessible
		]
		
		query = addAccessGroupWhenPresent(query)
		query = addSynchronizableIfRequired(query, addingItems: true)
		lastQueryParameters = query
		
		lastResultCode = SecItemAdd(query as CFDictionary, nil)
		
		return lastResultCode == noErr
	}
	
	/**
	
	Stores the boolean value in the keychain item under the given key.
	
	- parameter key: Key under which the value is stored in the keychain.
	- parameter value: Boolean to be written to the keychain.
	- parameter withAccess: Value that indicates when your app needs access to the value in the keychain item. By default the .AccessibleWhenUnlocked option is used that permits the data to be accessed only while the device is unlocked by the user.
	
	- returns: True if the value was successfully written to the keychain.
	
	*/
	@discardableResult
	func set(_ value: Bool, forKey key: String,
	         withAccess access: KeychainSwiftAccessOptions? = nil) -> Bool {
  
		let bytes: [UInt8] = value ? [1] : [0]
		let data = Data(bytes)
		
		return set(data, forKey: key, withAccess: access)
	}
	
	/**
	
	Retrieves the text value from the keychain that corresponds to the given key.
	
	- parameter key: The key that is used to read the keychain item.
	- returns: The text value from the keychain. Returns nil if unable to read the item.
	
	*/
	func get(_ key: String) -> String? {
		if let data = getData(key) {
			
			if let currentString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String? {
				return currentString
			}
			
			lastResultCode = -67853 // errSecInvalidEncoding
		}
		
		return nil
	}
	
	/**
	
	Retrieves the data from the keychain that corresponds to the given key.
	
	- parameter key: The key that is used to read the keychain item.
	- returns: The text value from the keychain. Returns nil if unable to read the item.
	
	*/
	func getData(_ key: String) -> Data? {
		let prefixedKey = keyWithPrefix(key)
		
		var query: [String: Any] = [
			KeychainSwiftConstants.klass       : kSecClassGenericPassword,
			KeychainSwiftConstants.attrAccount : prefixedKey,
			KeychainSwiftConstants.returnData  : kCFBooleanTrue as Any,
			KeychainSwiftConstants.matchLimit  : kSecMatchLimitOne
		]
		
		query = addAccessGroupWhenPresent(query)
		query = addSynchronizableIfRequired(query, addingItems: false)
		lastQueryParameters = query
		
		var result: AnyObject?
		
		lastResultCode = withUnsafeMutablePointer(to: &result) {
			SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
		}
		
		if lastResultCode == noErr { return result as? Data }
		
		return nil
	}
	
	/**
	
	Retrieves the boolean value from the keychain that corresponds to the given key.
	
	- parameter key: The key that is used to read the keychain item.
	- returns: The boolean value from the keychain. Returns nil if unable to read the item.
	
	*/
	func getBool(_ key: String) -> Bool? {
		guard let data = getData(key) else { return nil }
		guard let firstBit = data.first else { return nil }
		return firstBit == 1
	}
	
	/**
	
	Deletes the single keychain item specified by the key.
	
	- parameter key: The key that is used to delete the keychain item.
	- returns: True if the item was successfully deleted.
	
	*/
	@discardableResult
	func delete(_ key: String) -> Bool {
		let prefixedKey = keyWithPrefix(key)
		
		var query: [String: Any] = [
			KeychainSwiftConstants.klass       : kSecClassGenericPassword,
			KeychainSwiftConstants.attrAccount : prefixedKey
		]
		
		query = addAccessGroupWhenPresent(query)
		query = addSynchronizableIfRequired(query, addingItems: false)
		lastQueryParameters = query
		
		lastResultCode = SecItemDelete(query as CFDictionary)
		
		return lastResultCode == noErr
	}
	
	/**
	
	Deletes all Keychain items used by the app. Note that this method deletes all items regardless of the prefix settings used for initializing the class.
	
	- returns: True if the keychain items were successfully deleted.
	
	*/
	@discardableResult
	func clear() -> Bool {
		var query: [String: Any] = [ kSecClass as String : kSecClassGenericPassword ]
		query = addAccessGroupWhenPresent(query)
		query = addSynchronizableIfRequired(query, addingItems: false)
		lastQueryParameters = query
		
		lastResultCode = SecItemDelete(query as CFDictionary)
		
		return lastResultCode == noErr
	}
	
	/// Returns the key with currently set prefix.
	func keyWithPrefix(_ key: String) -> String {
		return "\(keyPrefix)\(key)"
	}
	
	func addAccessGroupWhenPresent(_ items: [String: Any]) -> [String: Any] {
		guard let accessGroup = accessGroup else { return items }
		
		var result: [String: Any] = items
		result[KeychainSwiftConstants.accessGroup] = accessGroup
		return result
	}
	
	/**
 
	Adds kSecAttrSynchronizable: kSecAttrSynchronizableAny` item to the dictionary when the `synchronizable` property is true.
	
	- parameter items: The dictionary where the kSecAttrSynchronizable items will be added when requested.
	- parameter addingItems: Use `true` when the dictionary will be used with `SecItemAdd` method (adding a keychain item). For getting and deleting items, use `false`.
	
	- returns: the dictionary with kSecAttrSynchronizable item added if it was requested. Otherwise, it returns the original dictionary.
 
	*/
	func addSynchronizableIfRequired(_ items: [String: Any], addingItems: Bool) -> [String: Any] {
		if !synchronizable { return items }
		var result: [String: Any] = items
		result[KeychainSwiftConstants.attrSynchronizable] = addingItems == true ? true : kSecAttrSynchronizableAny
		return result
	}
}
