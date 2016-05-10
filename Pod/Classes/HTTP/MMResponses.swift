//
//  MMResponses.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//  
//

import Freddy

typealias MMRegistrationResult = Result<MMHTTPRegistrationResponse>
typealias MMDeliveryReportingResult = Result<MMHTTPDeliveryReportingResponse>
typealias MMFetchMessagesResult = Result<MMHTTPFetchMessagesResponse>
typealias MMSaveEmailResult = Result<MMHTTPSaveEmailResponse>
typealias MMSaveMSISDNResult = Result<MMHTTPSaveMSISDNResponse>
typealias MMSeenMessagesResult = Result<MMHTTPSeenMessagesResponse>

final class MMHTTPRegistrationResponse {
    let internalId: String
	init(internalId: String) {
		self.internalId = internalId
	}
}

extension MMHTTPRegistrationResponse : JSONDecodable {
	convenience init(json value: JSON) throws {
		let internalId = try value.string(MMAPIKeys.kInternalRegistrationId)
		self.init(internalId: internalId)
	}
}


class MMHTTPEmptyResponse : JSONDecodable {
	required init(json value: JSON) throws {}
}

final class MMHTTPDeliveryReportingResponse: MMHTTPEmptyResponse { }
final class MMHTTPSaveEmailResponse: MMHTTPEmptyResponse { }
final class MMHTTPSaveMSISDNResponse: MMHTTPEmptyResponse { }
final class MMHTTPSeenMessagesResponse: MMHTTPEmptyResponse { }

final class MMHTTPFetchMessagesResponse {
    let messages : [MMMessage]?
    
    init(messages:[MMMessage]?) {
        self.messages = messages
    }
}

extension MMHTTPFetchMessagesResponse : JSONDecodable {
    convenience init(json value: JSON) throws {
        var payloads = [JSON]()
        do {
            payloads = try value.array(MMAPIKeys.kPayloads)
        } catch JSON.Error.KeyNotFound(key: MMAPIKeys.kPayloads){
            MMLogDebug("MMHTTPSyncMessagesResponse: nothing to fetch")
        }
		
		let messages = try payloads.map {try MMMessage(json: $0)}
        self.init(messages: messages)
    }
}

public func ==(lhs: MMMessage, rhs: MMMessage) -> Bool {
	return lhs.messageId == rhs.messageId
}

public struct MMMessage: Hashable, JSONDecodable {
	public init(json: JSON) throws {
        var result = [String: AnyObject]()
		self.messageId = try json.string(MMAPIKeys.kMessageId)
		result[MMAPIKeys.kMessageId] = self.messageId
		
		if let wrappedSupplId = try? json.string(MMAPIKeys.kSupplementaryId) {
			self.supplementaryId = wrappedSupplId
		} else {
			self.supplementaryId = messageId
		}
		
        result[MMAPIKeys.kSupplementaryId] = supplementaryId
        
        var aps = [NSObject: AnyObject]()
        if let sound = try? json[MMAPIKeys.kSound]?.string() {
            aps[MMAPIKeys.kSound] = sound
        }
        
        if let badge = try? json[MMAPIKeys.kBadge]?.int() {
            aps[MMAPIKeys.kBadge] = badge
        }
        
        if let body = try? json[MMAPIKeys.kBody]?.string() {
            var alert = [NSObject: AnyObject]()
            alert[MMAPIKeys.kBody] = body
            aps[MMAPIKeys.kAlert] = alert
        }
		
		if aps.count > 0 {
			result[MMAPIKeys.kAps] = aps
        }
        
		self.payload = result
        
        if let data = try? json.dictionary(MMAPIKeys.kData) {
            self.data = data
        }
	}
	
	public var hashValue: Int { return messageId.hashValue }
	
	let messageId: String
    let supplementaryId: String
	var payload: [String: AnyObject]?
    var data: [String: JSON]?
	
    init(messageId: String, supplementaryId: String, payload: [String: AnyObject]?) {
		self.messageId = messageId
        self.supplementaryId = supplementaryId
		self.payload = payload
	}
	
	init?(payload: [NSObject: AnyObject]) {
		guard let messageId = payload[MMAPIKeys.kMessageId] as? String,
            let payload = payload as? [String: AnyObject] else {
			return nil
		}
		
		let supplId = (payload[MMAPIKeys.kSupplementaryId] as? String) ?? messageId
		
        self.init(messageId: messageId, supplementaryId: supplId, payload: payload)
	}
	
	init(message: MessageManagedObject) {
		self.messageId = message.messageId
        self.supplementaryId = message.supplementaryId
	}
}

