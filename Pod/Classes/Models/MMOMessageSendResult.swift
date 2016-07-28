//
//  MMOMessageSendResult.swift
//  Pods
//
//  Created by okoroleva on 21.07.16.
//
//

import Foundation

public class MMOMessageSendResult : NSObject {
	public let resultMessages: [MOMessage]?
	public let error: NSError?
	
	init(resultMessages: [MOMessage]?, error: NSError?) {
		self.resultMessages = resultMessages
		self.error = error
	}
}
