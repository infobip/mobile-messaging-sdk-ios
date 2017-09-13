//
//  UserDataSynchronizationOperation.swift
//
//  Created by Andrey K. on 14/07/16.
//
//

import UIKit
import CoreData

class UserDataSynchronizationOperation: Operation {
	let user: MMUser
	let finishBlock: ((NSError?) -> Void)?
	let mmContext: MobileMessaging
	
	private let onlyFetching: Bool
	
	convenience init(fetchingOperationWithUser user: MMUser, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)? = nil) {
		self.init(user: user, onlyFetching: true, mmContext: mmContext, finishBlock: finishBlock)
	}
	
	convenience init(syncOperationWithUser user: MMUser, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)? = nil) {
		self.init(user: user, onlyFetching: false, mmContext: mmContext, finishBlock: finishBlock)
	}
	
	private init(user: MMUser, onlyFetching: Bool, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)? = nil) {
		self.user = user
		self.finishBlock = finishBlock
		self.onlyFetching = onlyFetching
		self.mmContext = mmContext
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[User data sync] Started...")
		user.persist()
		sendUserDataIfNeeded()
	}

	private func sendUserDataIfNeeded() {
		guard user.pushRegistrationId != nil else {
			MMLogDebug("[User data sync] There is no registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}

		if onlyFetching {
			MMLogDebug("[User data sync] fetching from server...")
			fetchUserData(externalId: user.externalId)
		} else  {
			MMLogDebug("[User data sync] sending user data updates to the server...")
			syncUserData(customUserDataValues: user.customData, externalId: user.externalId, predefinedUserData: user.rawPredefinedData)
		}
	}
	
	private func fetchUserData(externalId: String?) {
		mmContext.remoteApiManager.fetchUserData(externalUserId: externalId,
		                                         completion:
        { result in
			self.handleResult(result)
			self.finishWithError(result.error)
		})
	}
	
	private func syncUserData(customUserDataValues: [String: CustomUserDataValue]?, externalId: String?, predefinedUserData: UserDataDictionary?) {
		mmContext.remoteApiManager.syncUserData(externalUserId: externalId,
		                                 predefinedUserData: predefinedUserData,
		                                 customUserData: customUserDataValues)
		{ result in
			self.handleResult(result)
			self.finishWithError(result.error ?? result.value?.error?.foundationError)
		}
	}

	private func handleResult(_ result: UserDataSyncResult) {
		switch result {
		case .Success(let response):
			
			let newCustomUserData = response.customData?.reduce(nil, { (result: [String: CustomUserDataValue]?, element: CustomUserData) -> [String: CustomUserDataValue]? in
				if let value = element.dataValue {
					var result = result ?? [:]
					result[element.dataKey] = value
					return result
				} else {
					return result
				}
			}) ?? nil
			
			user.customData = newCustomUserData
			user.predefinedData = response.predefinedData as? [String: String]
			user.resetNeedToSync()
			guard !isCancelled else {
				return
			}
			user.persist()
			NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationUserDataSynced, userInfo: nil)
			MMLogDebug("[User data sync] successfully synced")
			
		case .Failure(let error):
			MMLogError("[User data sync] sync request failed with error: \(String(describing: error))")
			return
		case .Cancel:
			MMLogError("[User data sync] sync request cancelled.")
			return
		}
	}

	override func finished(_ errors: [NSError]) {
		MMLogDebug("[User data sync] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}

struct CustomUserData: DictionaryRepresentable {
	let dataKey: String
	let dataValue: CustomUserDataValue?

	init(dataKey: String, dataValue: UserDataFoundationTypes) {
		self.dataKey = dataKey
		if dataValue is NSNull {
			self.dataValue = nil
		} else {
			self.dataValue = CustomUserDataValue(withFoundationValue: dataValue)
		}
	}

	init?(dictRepresentation dict: DictionaryRepresentation) {
		guard let key = dict.first?.0 else {
			return nil
		}
		dataKey = key
		if	let valueDict = dict.first?.1 as? [String: AnyObject] {
			dataValue = CustomUserDataValue(withJSONDict: valueDict)
		} else {
			dataValue = nil
		}
	}

	var dictionaryRepresentation: DictionaryRepresentation {
		if let dataValue = dataValue, let valueDict = dataValue.jsonDictRepresentation {
			return [dataKey: valueDict]
		} else {
			return [dataKey: NSNull()]
		}
	}

	func mapToCoreDataCompatibleDictionary() -> [String: AnyObject]? {
		var result: [String: AnyObject]?
		if let value = dataValue, let type = value.dataType {
			var dict = [String: AnyObject]()
			switch type {
			case .string:
				if let stringValue = value.dataValue as? NSString {
					dict[dataKey] = stringValue
				}
			case .number:
				if let numberValue = value.dataValue as? NSNumber {
					dict[dataKey] = numberValue
				}
			case .date:
				if let dateValue = value.dataValue as? NSDate {
					dict[dataKey] = dateValue
				}
			}
			result = dict
		} else {
			var dict = [String: AnyObject]()
			dict[dataKey] = nil
			result = dict
		}
		return result
	}
}

enum UserDataServiceTypes: String {
	case string = "String"
	case number = "Number"
	case date = "Date"
}

@objc public protocol UserDataFoundationTypes: AnyObject {}
extension NSDate: UserDataFoundationTypes {}
extension NSNumber: UserDataFoundationTypes {}
extension NSString: UserDataFoundationTypes {}
extension NSNull: UserDataFoundationTypes {}

public final class CustomUserDataValue: NSObject, ExpressibleByStringLiteral, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
	let dataType: UserDataServiceTypes?
	let dataValue: UserDataFoundationTypes

//MARK: - Accessors
	public var string: String? {
		guard let type = dataType, let stringValue = dataValue as? NSString , type == .string else {
			return nil
		}
		return stringValue as String
	}
	public var date: NSDate? {
		guard let type = dataType, let dateValue = dataValue as? NSDate , type == .date else {
			return nil
		}
		return dateValue
	}
	public var number: NSNumber? {
		guard let type = dataType, let numberValue = dataValue as? NSNumber , type == .number else {
			return nil
		}
		return numberValue
	}
	public var double: Double? {
		guard let type = dataType, let numberValue = dataValue as? NSNumber , type == .number else {
			return nil
		}
		return CustomUserDataValue.isInteger(number: numberValue) ? nil : numberValue.doubleValue
	}
	public var integer: Int? {
		guard let type = dataType, let numberValue = dataValue as? NSNumber , type == .number else {
			return nil
		}
		return CustomUserDataValue.isInteger(number: numberValue) ? numberValue.intValue : nil
	}
//MARK: - Literals
	convenience public init(integerLiteral value: Int) {
		self.init(integer: value)
	}

	convenience public init(floatLiteral value: Double) {
		self.init(double: value)
	}

	convenience public init(stringLiteral value: String) {
		self.init(string: value)
	}

	convenience public init(extendedGraphemeClusterLiteral value: String) {
		self.init(string: value)
	}

	convenience public init(unicodeScalarLiteral value: String) {
		self.init(string: value)
	}

//MARK: - Init
	init(dataType: UserDataServiceTypes, dataValue: UserDataFoundationTypes) {
		self.dataValue = dataValue
		self.dataType = dataType
	}
	public init(date: NSDate) {
		dataValue = date
		dataType = .date
	}
	public init(integer: Int) {
		dataValue = NSNumber(value: integer)
		dataType = .number
	}
	public init(double: Double) {
		dataValue = NSNumber(value: double)
		dataType = .number
	}
	public init(string: String) {
		dataValue = string as NSString
		dataType = .string
	}
	public init(null: NSNull) {
		dataValue = null
		dataType = nil
	}

	static func isInteger(number: NSNumber) -> Bool {
		return floor(number.doubleValue) == number.doubleValue
	}

	convenience init?(withFoundationValue value: UserDataFoundationTypes) {
		switch value {
		case let string as NSString:
			self.init(string: string as String)
		case let number as NSNumber:
			if CustomUserDataValue.isInteger(number: number) {
				self.init(integer: number.intValue)
			} else {
				self.init(double: number.doubleValue)
			}
		case let date as NSDate:
			self.init(date: date)
		case let null as NSNull:
			self.init(null: null)
		default:
			return nil
		}
	}

	convenience init?(withJSONDict valueDict: [String: AnyObject]) {
		guard	let value = valueDict["value"] as? UserDataFoundationTypes,
				let dataTypeString = valueDict["type"] as? String,
				let type = UserDataServiceTypes(rawValue: dataTypeString)
			else
		{
			return nil
		}

		switch type {
		case .date:
			if let value = value as? String, let date = DateStaticFormatters.ISO8601SecondsFormatter.date(from: value) {
				self.init(date: date as NSDate)
				return
			}
		case .number:
			if let number = value as? NSNumber {
				self.init(withFoundationValue: number)
				return
			}
		case .string:
			if let string = value as? String {
				self.init(string: string)
				return
			}
		}
		return nil
	}

	var jsonDictRepresentation: [String: AnyObject]? {
		guard let dataType = dataType else {
			return nil
		}
		let jsonDictValue: AnyObject
		switch dataType {
		case .date:
			guard let date = dataValue as? Date else {
				return nil
			}
			jsonDictValue = DateStaticFormatters.ISO8601SecondsFormatter.string(from: date) as NSString
		case .number:
			guard let number = dataValue as? NSNumber else {
				return nil
			}
			jsonDictValue = number
		case .string:
			guard let string = dataValue as? NSString else {
				return nil
			}
			jsonDictValue = string
		}
		return ["type": dataType.rawValue as NSString, "value": jsonDictValue]
	}
}
