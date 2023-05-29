//
//  MMInboxService.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 25.02.2022.
//

import Foundation

public class MMInboxService: MobileMessagingService {
    private let q: DispatchQueue
    static var sharedInstance: MMInboxService?
    
    init(mmContext: MobileMessaging) {
        self.q = DispatchQueue(label: "inbox-service", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        super.init(mmContext: mmContext, uniqueIdentifier: "MMInboxService")
    }
    
    /**
     Asynchronously fetches inbox data for authorised user. Uses access token (JWT in a strictly predefined format) for authorization.
     - parameter token: Access token (JWT in a strictly predefined format) required for current user to have access to the Inbox messages.
     - parameter externalUserId: External User ID is meant to be an ID of a user in an external (non-Infobip) service.
     - parameter options: Filtering options applied to messages list in response.
     - parameter completion: The block to execute after the server responded.
     - parameter inbox: Inbox object containing list of messages and message counters.
     - parameter error: Optional error.
     */
    public func fetchInbox(token: String, externalUserId: String, options: MMInboxFilterOptions?, completion: @escaping (_ inbox: MMInbox?, _ error: NSError?) -> Void) {
        doFetchInbox(token: token, externalUserId: externalUserId, options: options, completion: completion)
    }
    
    /**
     Asynchronously fetches inbox data for authorised user. Uses Application Code for authorization.
     - Attention: This version of API uses Application Code (or API key) based authorization. This is not the most secure way of authorization because it is heavily dependent on how secure is your Application Code stored on a device. If it's hardcoded, consider obfuscating the Application Code string (we can recommend the following open-source library for string obfuscation: [UAObfuscatedString](https://github.com/UrbanApps/UAObfuscatedString)).
     - Remark: If the security is a crucial aspect, consider using the alternative `fetchInbox` API that is based on access token authorization:
    ```
    func fetchInbox(token: String,
                    externalUserId: String,
                    options: MMInboxFilterOptions?,
                    completion: @escaping (_ inbox: MMInbox?, _ error: NSError?) -> Void)
    ```
     
     
     - parameter externalUserId: External User ID is meant to be an ID of a user in an external (non-Infobip) service.
     - parameter options: Filtering options applied to messages list in response.
     - parameter completion: The block to execute after the server responded.
     - parameter inbox: Inbox object containing list of messages and message counters.
     - parameter error: Optional error.
     */
    public func fetchInbox(externalUserId: String, options: MMInboxFilterOptions?, completion: @escaping (_ inbox: MMInbox?, _ error: NSError?) -> Void) {
        doFetchInbox(token: nil, externalUserId: externalUserId, options: options, completion: completion)
    }
    
    /**
     Asynchronously marks inbox message as seen.
     
     - parameter externalUserId: External User ID is meant to be an ID of a user in an external (non-Infobip) service.
     - parameter messageIds: Array of inbox messages identifiers that need to be marked as seen.
     - parameter completion: The block to execute after the server responded.
     - parameter error: Optional error.
     */
    public func setSeen(externalUserId: String, messageIds: [String], completion: @escaping (_ error: NSError?) -> Void) {
        let body = InboxSeenRequestDataMapper.requestBody(messageIds: messageIds, externalUserId: externalUserId, seenDate: MMDate().now)
        q.async {
            self.mmContext.remoteApiProvider.sendSeenStatus(
                applicationCode: self.mmContext.applicationCode,
                pushRegistrationId: self.mmContext.currentInstallation().pushRegistrationId,
                body: body,
                queue: DispatchQueue.main) { result in
                    completion(result.error)
                }
        }
    }
    
    public override var systemData: [String: AnyHashable]? {
        return ["inbox": true]
    }
    
    private func doFetchInbox(token: String?, externalUserId: String, options: MMInboxFilterOptions?, completion: @escaping (_ inbox: MMInbox?, _ error: NSError?) -> Void) {
        q.async {
            self.mmContext.remoteApiProvider.getInbox(
                applicationCode: self.mmContext.applicationCode,
                accessToken: token,
                externalUserId: externalUserId,
                from: options?.fromDateTime,
                to: options?.toDateTime,
                limit: options?.limit,
                topic: options?.topic,
                queue: DispatchQueue.main) { result in
                    completion(result.value, result.error)
                }
        }
    }
    
    public override func stopService(_ completion: @escaping (Bool) -> Void) {
        super.stopService(completion)
        MMInboxService.sharedInstance = nil
    }
}
