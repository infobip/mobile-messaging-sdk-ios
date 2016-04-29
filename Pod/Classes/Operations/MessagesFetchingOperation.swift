//
//  MessagesFetchingOperation.swift
//  Pods
//
//  Created by Andrey K. on 18/04/16.
//
//

import UIKit
import CoreData

class MessagesFetchingOperation: Operation {
	var context: NSManagedObjectContext
	var finishBlock: (MMFetchMessagesResult -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	var result = MMFetchMessagesResult.Failure(NSError(type: .UnknownError))
	
	init(context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (MMFetchMessagesResult -> Void)? = nil) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		
		super.init()
		
		self.addCondition(RegistrationCondition())
	}
	
	override func execute() {
		guard let internalId = MobileMessaging.currentInstallation?.internalId else {
			self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		context.performBlockAndWait {
			var notReportedMessageIds = [String]()
			if let nonReportedMessages = MessageManagedObject.MR_findAllWithPredicate(NSPredicate(format: "reportSent == false"), inContext: self.context) as? [MessageManagedObject] where nonReportedMessages.count > 0 {
				notReportedMessageIds = nonReportedMessages.map { $0.messageId }
			}
			
			let request = MMGetMessagesRequest(messageIds: notReportedMessageIds, internalId: internalId)
			self.remoteAPIQueue.performRequest(request) {
				self.handleFetchResult($0)
			}
		}
	}
	
	private func handleFetchResult(result: MMFetchMessagesResult) {
		self.result = result
		switch result {
		case .Success(let fetchResponse):
			MMLogInfo("Messages fetching request succeded: received \(fetchResponse.messages?.count) new messages: \(fetchResponse.messages)")
			self.finish()
		case .Failure(let error):
			MMLogError("Messages fetching request failed with error: \(error)")
			self.finishWithError(error)
		case .Cancel:
			self.finish()
		}
	}
	
	private func handleMessageOperation(messages: [MMMessage]) -> MessageHandlingOperation {
		return MessageHandlingOperation(userInfos: messages.flatMap { $0.payload },
		                                context: self.context,
		                                remoteAPIQueue: self.remoteAPIQueue,
		                                newMessageReceivedCallback: nil) { error in
											
											var finalResult = self.result
											if let error = error {
												finalResult = MMFetchMessagesResult.Failure(error)
											}
											self.finishBlock?(finalResult)
										}
	}
	
	override func finished(errors: [NSError]) {
		switch result {
		case .Success(let fetchResponse):
			if let messages = fetchResponse.messages where messages.count > 0 {
				self.produceOperation(self.handleMessageOperation(messages))
			} else {
				self.finishBlock?(result)
			}
		default:
			self.finishBlock?(result)
		}
	}
}
