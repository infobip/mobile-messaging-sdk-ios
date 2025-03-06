//
// TegKeychainConstants.swift
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

import Foundation
import Security

/// Constants used by the library
struct KeychainSwiftConstants {
	/// Specifies a Keychain access group. Used for sharing Keychain items between apps.
	static var accessGroup: String { return toString(kSecAttrAccessGroup) }
	
	/**
	
	A value that indicates when your app needs access to the data in a keychain item. The default value is AccessibleWhenUnlocked. For a list of possible values, see KeychainSwiftAccessOptions.
	
	*/
	static var accessible: String { return toString(kSecAttrAccessible) }
	
	/// Used for specifying a String key when setting/getting a Keychain value.
	static var attrAccount: String { return toString(kSecAttrAccount) }
	
	/// Used for specifying synchronization of keychain items between devices.
	static var attrSynchronizable: String { return toString(kSecAttrSynchronizable) }
	
	/// An item class key used to construct a Keychain search dictionary.
	static var klass: String { return toString(kSecClass) }
	
	/// Specifies the number of values returned from the keychain. The library only supports single values.
	static var matchLimit: String { return toString(kSecMatchLimit) }
	
	/// A return data type used to get the data from the Keychain.
	static var returnData: String { return toString(kSecReturnData) }
	
	/// Used for specifying a value when setting a Keychain value.
	static var valueData: String { return toString(kSecValueData) }
	
	static func toString(_ value: CFString) -> String {
		return value as String
	}
}


