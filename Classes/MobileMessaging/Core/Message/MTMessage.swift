//
//  MTMessage.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 18/10/2017.
//

import Foundation

@objcMembers
open class MM_MTMessage: MMBaseMessage, NamedLogger {

	/// Contains info about the action was applied to the message
	public var appliedAction: MMNotificationAction?

	/// Structure representing APS payload attributes
	public var aps: MMPushPayloadAPS

	/// Servers datetime
	public var sendDateTime: TimeInterval

	/// Date of message expiration (validity period)
	public var inAppExpiryDateTime: TimeInterval?

	/// Custom title for "Dismiss" button for in-app message alert
	public var inAppDismissTitle: String?

	/// Custom title for "Open" button for in-app message alert
	public var inAppOpenTitle: String?

	/// Messages seen status
	public var seenStatus: MMSeenStatus

	/// Datetime that message was seen
	public var seenDate: Date?

	/// Flag indicates whether the message was reported on delivery
	public var isDeliveryReportSent: Bool

	/// Datetime that message was reported on delivery
	public var deliveryReportedDate: Date?

	/// Title of the message. If message title may be localized ("alert.title-loc-key" attribute is present and refers to an existing localized string), the localized string is returned, otherwise the value of "alert.title" attribute is returned if present.
	public var title: String? { return String.localizedUserNotificationStringOrFallback(key: title_loc_key, args: title_loc_args, fallback: aps.title) }

	/// Localization key of the message title.
	public var title_loc_key: String? { return aps.title_loc_key }

	/// Localization args of the message title.
	public var title_loc_args: [String]? { return aps.title_loc_args }

	/// Localization key of the message text.
	public var loc_key: String? { return aps.loc_key }

	/// Localization args of the message.
	public var loc_args: [String]? { return aps.loc_args }

	/// Sound of the message.
	public var sound: String? { return aps.sound }

	/// Badge counter
	public var badge: Int? { return aps.badge }

	/// Interactive category Id
	public var category: String? { return aps.category }

	/// Defines if a message is silent. Silent messages have neither text nor sound attributes.
	public var isSilent: Bool { return isSilentInternalData(internalData) }

	/// URL representing rich notification content
	public var contentUrl: String? {
		if let atts = internalData?[Consts.InternalDataKeys.attachments] as? [MMStringKeyPayload], let firstOne = atts.first {
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
    
    public var browserUrl: URL? {
        if let urlString = internalData?[Consts.InternalDataKeys.browserUrl] as? String {
            return URL.init(string: urlString)
        } else {
            return nil
        }
    }

    public var deeplink: URL? {
        if let urlString = internalData?[Consts.InternalDataKeys.deeplink] as? String {
            return URL.init(string: urlString)
        } else {
            return nil
        }
    }
	
	public var showInApp: Bool {
		return internalData?[Consts.InternalDataKeys.showInApp] as? Bool ?? false
	}
	
	public var inAppStyle: MMInAppNotificationStyle? {
		let defaultStyle = showInApp ? MMInAppNotificationStyle.Modal : nil
		let resolvedStyle: MMInAppNotificationStyle?
		if let rawValue = internalData?[Consts.InternalDataKeys.inAppStyle] as? Int16 {
			resolvedStyle = MMInAppNotificationStyle(rawValue: rawValue) ?? defaultStyle
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
    
    public var topic: String? {
        return originalPayload.mm_inbox?[Consts.InternalDataKeys.topic] as? String
    }

	/// Indicates whether the message represents a geo campaign subscription
	public var isGeoSignalingMessage: Bool {
		return internalData?[Consts.InternalDataKeys.geo] != nil && isSilent
	}

	/// APNS payload (`aps` object) sent with the silent push notifications
	public var silentData: MMStringKeyPayload? {
		return internalData?[Consts.InternalDataKeys.silent] as? MMStringKeyPayload
	}

	/// Internal data for internal use
	public var internalData: MMStringKeyPayload? {
		return originalPayload[Consts.APNSPayloadKeys.internalData] as? MMStringKeyPayload
	}
	
	public override var customPayload: MMStringKeyPayload? {
		get {
			return originalPayload[Consts.APNSPayloadKeys.customPayload] as? MMStringKeyPayload
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
    	
	public convenience init?(messageSyncResponseJson json: JSON) {
		if let payload = json.dictionaryObject {
			self.init(payload: payload,
					  deliveryMethod: .pull,
					  seenDate: nil,
					  deliveryReportDate: nil,
                      seenStatus: (payload.mm_inbox?[Consts.InternalDataKeys.seen] as? Bool) == true ? .SeenNotSent : .NotSeen,
					  isDeliveryReportSent: false)
		} else {
			return nil
		}
		self.deliveryMethod = .pull
	}
	
	/// Initializes the MTMessage from Message storage's message
	convenience init?(messageStorageMessageManagedObject m: Message) {
		guard let deliveryMethod = MMMessageDeliveryMethod(rawValue: m.deliveryMethod) else {
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
	public init?(payload: MMAPNSPayload, deliveryMethod: MMMessageDeliveryMethod, seenDate: Date?, deliveryReportDate: Date?, seenStatus: MMSeenStatus, isDeliveryReportSent: Bool) {
		guard 	let payload = payload as? MMStringKeyPayload,
			let messageId = payload[Consts.APNSPayloadKeys.messageId] as? String else
		{
			return nil
		}
		//workaround for cordova
		let internData = payload[Consts.APNSPayloadKeys.internalData] as? MMStringKeyPayload
		let nativeAPS = payload[Consts.APNSPayloadKeys.aps] as? MMStringKeyPayload
		
		if isSilentInternalData(internData) {
			if let silentAPS = (payload[Consts.APNSPayloadKeys.internalData] as? MMStringKeyPayload)?[Consts.InternalDataKeys.silent] as? MMStringKeyPayload {
				self.aps = MMPushPayloadAPS.SilentAPS(apsByMerging(nativeAPS: nativeAPS ?? [:], withSilentAPS: silentAPS))
			} else {
				return nil
			}
		} else if let nativeAPS = nativeAPS {
			self.aps = MMPushPayloadAPS.NativeAPS(nativeAPS)
		} else {
			return nil
		}
		
		if let sendDateTimeMillis = (payload[Consts.APNSPayloadKeys.internalData] as? MMStringKeyPayload)?[Consts.InternalDataKeys.sendDateTime] as? Double {
			self.sendDateTime = sendDateTimeMillis/1000
		} else {
			self.sendDateTime = MobileMessaging.date.now.timeIntervalSince1970
		}
		if let expirationMillis = (payload[Consts.APNSPayloadKeys.internalData] as? MMStringKeyPayload)?[Consts.InternalDataKeys.inAppExpiryDateTime] as? Double {
			self.inAppExpiryDateTime = expirationMillis/1000
		}
		if let str = (payload[Consts.APNSPayloadKeys.internalData] as? MMStringKeyPayload)?[Consts.InternalDataKeys.inAppDismissTitle] as? String {
			self.inAppDismissTitle = str
		}
		if let str = (payload[Consts.APNSPayloadKeys.internalData] as? MMStringKeyPayload)?[Consts.InternalDataKeys.inAppOpenTitle] as? String {
			self.inAppOpenTitle = str
		}
		self.seenStatus = seenStatus
		self.isDeliveryReportSent = isDeliveryReportSent
		self.seenDate = seenDate
		self.deliveryReportedDate = deliveryReportDate
		
		super.init(messageId: messageId, direction: .MT, originalPayload: payload, deliveryMethod: deliveryMethod)
	}
    
    public class func make(withPayload payload: MMAPNSPayload) -> MM_MTMessage? {
        return MM_MTMessage(payload: payload,
                         deliveryMethod: .undefined,
                         seenDate: nil,
                         deliveryReportDate: nil,
                         seenStatus: .NotSeen,
                         isDeliveryReportSent: false)
    }
    
    public class func isCorrectPayload(_ payload: MMAPNSPayload) -> Bool {
        return MM_MTMessage(payload: payload,
                            deliveryMethod: .push,
                            seenDate: nil,
                            deliveryReportDate: nil,
                            seenStatus: .NotSeen,
                            isDeliveryReportSent: false) != nil
    }
}

func isSilentInternalData(_ internalData: MMStringKeyPayload?) -> Bool {
	return internalData?[Consts.InternalDataKeys.silent] != nil
}
