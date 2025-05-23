//
// KeychainSwiftAccessOptions.swift
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

/**

These options are used to determine when a keychain item should be readable. The default value is AccessibleWhenUnlocked.

*/
enum KeychainSwiftAccessOptions {
	
	/**
	
	The data in the keychain item can be accessed only while the device is unlocked by the user.
	
	This is recommended for items that need to be accessible only while the application is in the foreground. Items with this attribute migrate to a new device when using encrypted backups.
	
	This is the default value for keychain items added without explicitly setting an accessibility constant.
	
	*/
	case accessibleWhenUnlocked
	
	/**
	
	The data in the keychain item can be accessed only while the device is unlocked by the user.
	
	This is recommended for items that need to be accessible only while the application is in the foreground. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.
	
	*/
	case accessibleWhenUnlockedThisDeviceOnly
	
	/**
	
	The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user.
	
	After the first unlock, the data remains accessible until the next restart. This is recommended for items that need to be accessed by background applications. Items with this attribute migrate to a new device when using encrypted backups.
	
	*/
	case accessibleAfterFirstUnlock
	
	/**
	
	The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user.
	
	After the first unlock, the data remains accessible until the next restart. This is recommended for items that need to be accessed by background applications. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.
	
	*/
	case accessibleAfterFirstUnlockThisDeviceOnly
	
	/**
	
	The data in the keychain item can always be accessed regardless of whether the device is locked.
	
	This is not recommended for application use. Items with this attribute migrate to a new device when using encrypted backups.
	
	*/
	case accessibleAlways
	
	/**
	
	The data in the keychain can only be accessed when the device is unlocked. Only available if a passcode is set on the device.
	
	This is recommended for items that only need to be accessible while the application is in the foreground. Items with this attribute never migrate to a new device. After a backup is restored to a new device, these items are missing. No items can be stored in this class on devices without a passcode. Disabling the device passcode causes all items in this class to be deleted.
	
	*/
	case accessibleWhenPasscodeSetThisDeviceOnly
	
	/**
	
	The data in the keychain item can always be accessed regardless of whether the device is locked.
	
	This is not recommended for application use. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.
	
	*/
	case accessibleAlwaysThisDeviceOnly
	
	static var defaultOption: KeychainSwiftAccessOptions {
		return .accessibleWhenUnlocked
	}
	
	var value: String {
		switch self {
		case .accessibleWhenUnlocked:
			return toString(kSecAttrAccessibleWhenUnlocked)
			
		case .accessibleWhenUnlockedThisDeviceOnly:
			return toString(kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
			
		case .accessibleAfterFirstUnlock:
			return toString(kSecAttrAccessibleAfterFirstUnlock)
			
		case .accessibleAfterFirstUnlockThisDeviceOnly:
			return toString(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
			
		case .accessibleAlways:
			return toString(kSecAttrAccessibleAfterFirstUnlock)
			
		case .accessibleWhenPasscodeSetThisDeviceOnly:
			return toString(kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
			
		case .accessibleAlwaysThisDeviceOnly:
			return toString(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
		}
	}
	
	func toString(_ value: CFString) -> String {
		return KeychainSwiftConstants.toString(value)
	}
}
