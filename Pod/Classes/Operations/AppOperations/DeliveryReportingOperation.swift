//
//  DeliveryReportingOperation.swift
//  Pods
//
//  Created by Andrey K. on 18/04/16.
//
//

import UIKit
import CoreData

class DeliveryReportingOperation: Operation {
	var context: NSManagedObjectContext
	var finishBlock: (NSError? -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	
	init(context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (NSError? -> Void)? = nil) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
	}
	
	override func execute() {
		self.context.performBlockAndWait {
			self.deliverReports()
		}
	}
	
	private func deliverReports() {
		guard let nonReportedMessages = MessageManagedObject.MR_findAllWithPredicate(NSPredicate(format: "reportSent == false"), inContext: self.context) as? [MessageManagedObject]
			where nonReportedMessages.count > 0
			else
		{
			MMLogInfo("No delivery reports to sent. Finishing reporting...")
			finish()
			return
		}
		
		var nonReportedMessageIds = nonReportedMessages.map{ $0.messageId }
		let request = MMPostDeliveryReportRequest(messageIDs: nonReportedMessageIds)
		self.remoteAPIQueue.performRequest(request) { result in
			self.context.performBlockAndWait {
				switch result {
				case .Success:
					self.dequeueDeliveryReports(nonReportedMessageIds)
					MMLogInfo("Delivery report sent.")
					MMQueue.Main.queue.executeAsync {
						NSNotificationCenter.defaultCenter().postNotificationName(MMEventNotifications.kDeliveryReportSent, object: self, userInfo: [MMEventNotifications.kMessageIDsUserInfoKey: nonReportedMessageIds])
					}
				case .Failure(let error):
					MMLogError("Delivery reporting request failed with error: \(error)")
				case .Cancel:
					MMLogInfo("Delivery reporting cancelled")
					break
				}
				self.finishWithError(result.error)
			}
		}
	}
	
	private func dequeueDeliveryReports(messageIDs: [String]) {
		guard let messages = MessageManagedObject.MR_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIDs), inContext: context) as? [MessageManagedObject]
			where messages.count > 0
			else
		{
			return
		}
		
		for message in messages {
			message.reportSent = true
		}
		
		MMLogDebug("Marked as sent: \(messages.map{ $0.messageId })")
		context.MR_saveToPersistentStoreAndWait()
	}
	
	override func finished(errors: [NSError]) {
		finishBlock?(errors.first)
	}
}
