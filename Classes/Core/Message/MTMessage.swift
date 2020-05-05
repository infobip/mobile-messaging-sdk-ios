//
//  MTMessage.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 18/10/2017.
//

import Foundation

public protocol MTMessageProtocol {
	
	/// Contains info about the action was applied to the message
	var appliedAction: NotificationAction? {get set}
	
	/// Structure representing APS payload attributes
	var aps: PushPayloadAPS {get}
	
	/// Defines if a message is silent. Silent messages have neither text nor sound attributes.
	var isSilent: Bool {get}
	
	/// Title of the message. If message title may be localized ("alert.title-loc-key" attribute is present and refers to an existing localized string), the localized string is returned, otherwise the value of "alert.title" attribute is returned if present.
	var title: String? {get}
	
	/// Localization key of the message title.
	var title_loc_key: String? {get}
	
	/// Localization args of the message title.
	var title_loc_args: [String]? {get}
	
	/// Localization key of the message text.
	var loc_key: String? {get}
	
	/// Localization args of the message.
	var loc_args: [String]? {get}
	
	/// Sound of the message.
	var sound: String? {get}
	
	/// Interactive category Id
	var category: String? {get}
	
	/// Badge counter
	var badge: Int? {get}
	
	/// URL representing rich notification content
	var contentUrl: String? {get}
	
	/// Servers datetime
	var sendDateTime: TimeInterval {get} // seconds
	
	/// Date of message expiration (validity period)
	var inAppExpiryDateTime: TimeInterval? {get} // seconds
	
	/// Messages seen status
	var seenStatus: MMSeenStatus {get}
	
	/// Datetime that message was seen
	var seenDate: Date? {get}
	
	/// Flag indicates whether the message was reported on delivery
	var isDeliveryReportSent: Bool {get}
	
	/// Datetime that message was reported on delivery
	var deliveryReportedDate: Date? {get}
	
	/// Internal data for internal use
	var internalData: StringKeyPayload? {get}
	
	/// APNS payload (`aps` object) sent with the silent push notifications
	var silentData: StringKeyPayload? {get}
	
	/// Indicates whether the message represents a geo campaign subscription
	var isGeoSignalingMessage: Bool {get}
}

@objcMembers
public class MTMessage: BaseMessage, MTMessageProtocol {
	
	public var appliedAction: NotificationAction?
	
	public var aps: PushPayloadAPS
	
	public var sendDateTime: TimeInterval
	
	public var inAppExpiryDateTime: TimeInterval?
	
	public var seenStatus: MMSeenStatus
	
	public var seenDate: Date?
	
	public var isDeliveryReportSent: Bool
	
	public var deliveryReportedDate: Date?
	
	public var title: String? { return String.localizedUserNotificationStringOrFallback(key: title_loc_key, args: title_loc_args, fallback: aps.title) }
	
	public var title_loc_key: String? { return aps.title_loc_key }
	
	public var title_loc_args: [String]? { return aps.title_loc_args }
	
	public var loc_key: String? { return aps.loc_key }
	
	public var loc_args: [String]? { return aps.loc_args }
	
	public var sound: String? { return aps.sound }
	
	public var badge: Int? { return aps.badge }
	
	public var category: String? { return aps.category }
	
	public var isSilent: Bool { return isSilentInternalData(internalData) }
	
	public var contentUrl: String? {
		if let atts = internalData?[Consts.InternalDataKeys.attachments] as? [StringKeyPayload], let firstOne = atts.first {
			return firstOne[Consts.Attachments.Keys.url] as? String
		} else {
			return nil
		}
	}
	
	//	var downloadedPictureUrl: URL? //NOTE: this field may be used to keep url of downloaded content/cache
	
	public var webViewUrl: URL? {
		if let urlString = internalData?[Consts.InternalDataKeys.webViewUrl] as? String {
			return URL.init(string: urlString)
		} else {
			return nil
		}
	}
	
	public var showInApp: Bool {
		return internalData?[Consts.InternalDataKeys.showInApp] as? Bool ?? false
	}
	
	public var inAppStyle: InAppNotificationStyle? {
		let defaultStyle = showInApp ? InAppNotificationStyle.Modal : nil
		let resolvedStyle: InAppNotificationStyle?
		if let rawValue = internalData?[Consts.InternalDataKeys.inAppStyle] as? Int16 {
			resolvedStyle = InAppNotificationStyle(rawValue: rawValue) ?? defaultStyle
		} else {
			resolvedStyle = defaultStyle
		}
		return resolvedStyle
	}
	
	public var isExpired: Bool {
		if let expirationDateTime = inAppExpiryDateTime {
			return MobileMessaging.date.now.timeIntervalSince1970 > expirationDateTime
		} else {
			return false
		}
	}
	
	public var isGeoSignalingMessage: Bool {
		return internalData?[Consts.InternalDataKeys.geo] != nil && isSilent
	}
	
	public var silentData: StringKeyPayload? {
		return internalData?[Consts.InternalDataKeys.silent] as? StringKeyPayload
	}
	
	public var internalData: StringKeyPayload? {
		return originalPayload[Consts.APNSPayloadKeys.internalData] as? StringKeyPayload
	}
	
	public override var customPayload: StringKeyPayload? {
		get {
			return originalPayload[Consts.APNSPayloadKeys.customPayload] as? StringKeyPayload
		}
		set {}
	}
	
	public override var text: String? {
		get {
			return String.localizedUserNotificationStringOrFallback(key: loc_key, args: loc_args, fallback: aps.text)
		}
		set {}
	}
	
	public override var isChatMessage: Bool {
		guard let messageTypeValue = internalData?[Consts.InternalDataKeys.messageType] as? String else {
			return false
		}
		return messageTypeValue == Consts.APIValues.MessageTypeValues.chat
	}
	
	convenience init?(messageSyncResponseJson json: JSON) {
		if let payload = json.dictionaryObject {
			self.init(payload: payload,
					  deliveryMethod: .pull,
					  seenDate: nil,
					  deliveryReportDate: nil,
					  seenStatus: .NotSeen,
					  isDeliveryReportSent: false)
		} else {
			return nil
		}
		self.deliveryMethod = .pull
	}
	
	/// Initializes the MTMessage from Message storage's message
	convenience init?(messageStorageMessageManagedObject m: Message) {
		guard let deliveryMethod = MessageDeliveryMethod(rawValue: m.deliveryMethod) else {
			return nil
		}
		self.init(payload: m.payload,
				  deliveryMethod: deliveryMethod,
				  seenDate: m.seenDate,
				  deliveryReportDate: m.deliveryReportedDate,
				  seenStatus: MMSeenStatus(rawValue: m.seenStatusValue) ?? .NotSeen,
				  isDeliveryReportSent: m.isDeliveryReportSent)
	}
	
	/// Designated init
	public init?(payload: APNSPayload, deliveryMethod: MessageDeliveryMethod, seenDate: Date?, deliveryReportDate: Date?, seenStatus: MMSeenStatus, isDeliveryReportSent: Bool) {
		guard 	let payload = payload as? StringKeyPayload,
			let messageId = payload[Consts.APNSPayloadKeys.messageId] as? String else
		{
			return nil
		}
		//workaround for cordova
		let internData = payload[Consts.APNSPayloadKeys.internalData] as? StringKeyPayload
		let nativeAPS = payload[Consts.APNSPayloadKeys.aps] as? StringKeyPayload
		
		if isSilentInternalData(internData) {
			if let silentAPS = (payload[Consts.APNSPayloadKeys.internalData] as? StringKeyPayload)?[Consts.InternalDataKeys.silent] as? StringKeyPayload {
				self.aps = PushPayloadAPS.SilentAPS(apsByMerging(nativeAPS: nativeAPS ?? [:], withSilentAPS: silentAPS))
			} else {
				return nil
			}
		} else if let nativeAPS = nativeAPS {
			self.aps = PushPayloadAPS.NativeAPS(nativeAPS)
		} else {
			return nil
		}
		
		if let sendDateTimeMillis = (payload[Consts.APNSPayloadKeys.internalData] as? StringKeyPayload)?[Consts.InternalDataKeys.sendDateTime] as? Double {
			self.sendDateTime = sendDateTimeMillis/1000
		} else {
			self.sendDateTime = MobileMessaging.date.now.timeIntervalSince1970
		}
		if let expirationMillis = (payload[Consts.APNSPayloadKeys.internalData] as? StringKeyPayload)?[Consts.InternalDataKeys.inAppExpiryDateTime] as? Double {
			self.inAppExpiryDateTime = expirationMillis/1000
		}
		self.seenStatus = seenStatus
		self.isDeliveryReportSent = isDeliveryReportSent
		self.seenDate = seenDate
		self.deliveryReportedDate = deliveryReportDate
		
		super.init(messageId: messageId, direction: .MT, originalPayload: payload, deliveryMethod: deliveryMethod)
	}
}

func isSilentInternalData(_ internalData: StringKeyPayload?) -> Bool {
	return internalData?[Consts.InternalDataKeys.silent] != nil
}
