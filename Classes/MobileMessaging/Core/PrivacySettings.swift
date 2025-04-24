//
//  PrivacySettings.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01/11/2018.
//

import Foundation

/// The `MMPrivacySettings` class encapsulates privacy settings that affect the SDK behaviour and business logic.
@objcMembers
public class MMPrivacySettings: NSObject {
	/// A boolean variable that indicates whether the MobileMessaging SDK will be sending the carrier information to the server.
	///
	/// Default value is `false`.
	public var carrierInfoSendingDisabled: Bool = false

	/// A boolean variable that indicates whether the MobileMessaging SDK will be sending the system information such as OS version, device model, application version to the server.
	///
	/// Default value is `false`.
	public var systemInfoSendingDisabled: Bool = false

	/// A boolean variable that indicates whether the MobileMessaging SDK will be persisting the application code locally. This feature is a convenience to maintain SDK viability during debugging and possible application code changes.
	///
	/// Default value is `false`.
	/// - Warning: there might be situation when you want to switch between different Application Codes during development/testing. If you disable the application code persisting (value `true`), the SDK won't detect the application code changes, thus won't cleanup the old application code related data. You should manually invoke `MobileMessaging.cleanUpAndStop()` prior to start otherwise the SDK would not detect the application code change.
	public var applicationCodePersistingDisabled: Bool = false

	/// A boolean variable that indicates whether the MobileMessaging SDK will be persisting the user data locally. Persisting user data locally gives you quick access to the data and eliminates a need to implement it yourself.
	///
	/// Default value is `false`.
	public var userDataPersistingDisabled: Bool = false
}
