//
//  SeenStatusSendingOperation.swift
//
//  Created by Andrey K. on 05/07/16.
//
//

import UIKit
import CoreData

class SeenStatusSendingOperation: Operation {
	let context: NSManagedObjectContext
	let finishBlock: ((SeenStatusSendingResult) -> Void)?
	var result = SeenStatusSendingResult.Cancel
	let mmContext: MobileMessaging
	
	init(context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: ((SeenStatusSendingResult) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		self.mmContext = mmContext
	}

	override func execute() {
		context.perform {
			self.context.reset()
			guard let seenNotSentMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageTypeValue == \(MMMessageType.Default.rawValue) AND seenStatusValue == \(MMSeenStatus.SeenNotSent.rawValue) AND NOT(messageId MATCHES [c] '\(Consts.UUIDRegexPattern)')"), context: self.context), !seenNotSentMessages.isEmpty else
			{
				MMLogDebug("[Seen status reporting] There is no non-seen meessages to send to the server. Finishing...")
				self.finish()
				return
			}
			
			self.mmContext.remoteApiProvider.sendSeenStatus(
				applicationCode: self.mmContext.applicationCode,
				pushRegistrationId: self.mmContext.currentInstallation().pushRegistrationId,
				body: SeenReportMapper.requestBody(seenNotSentMessages),
				completion: { result in
					self.result = result
					self.handleSeenResult(result, messages: seenNotSentMessages) {
						self.finishWithError(result.error)
					}
			})
		}
	}
	
	private func handleSeenResult(_ result: SeenStatusSendingResult, messages: [MessageManagedObject], completion: @escaping () -> Void) {
		switch result {
		case .Success(_):
			MMLogDebug("[Seen status reporting] Request succeeded")

			context.performAndWait {
				messages.forEach { message in
					message.seenStatus = .SeenSent
				}
				self.context.MM_saveToPersistentStoreAndWait()
				self.updateMessageStorage(with: messages.map({ $0.messageId }), completion: completion)
			}
		case .Failure(let error):
			MMLogError("[Seen status reporting] Request failed with error: \(error.orNil)")
			completion()
		case .Cancel:
			completion()
			break
		}
	}
	
	private func updateMessageStorage(with messageIds: [String], completion: @escaping () -> Void) {
		guard !messageIds.isEmpty else {
			completion()
			return
		}
		let storages = mmContext.messageStorages.values
		storages.forEachAsync({ (storage, finishBlock) in
			storage.batchSeenStatusUpdate(messageIds: messageIds, seenStatus: .SeenSent, completion: finishBlock)
		}, completion: completion)
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Seen status reporting] finished: \(errors)")
		if let error = errors.first {
			result = SeenStatusSendingResult.Failure(error)
		}
		finishBlock?(result)
	}
}
