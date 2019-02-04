//
//  ChatHelper.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 02/11/2017.
//

import Foundation
import AudioToolbox

class ChatHelper : MessageStorageDelegate {
	func didInsertNewMessages(_ messages: [BaseMessage]) {
		if UIApplication.shared.applicationState == UIApplication.State.active {
			playReceivedMessageSound()
		} else {
			let id = MobileMessaging.sharedInstance?.internalData()
			id?.badgeNumber += 1
			id?.archiveCurrent()
		}
	}
	
	func didUpdateMessage(_ message: BaseMessage) {
		
	}
	
	func didRemoveMessages(_ messages: [BaseMessage]) {
		
	}
	
	static let defaultInstance = ChatHelper()
	
	//MARK: - Sounds
	func playSendMessageSound() {
		playSoundWithName("sendSound")
	}
	
	func playReceivedMessageSound() {
		playSoundWithName("message")
	}
	
	func playSoundWithName(_ name: String) {
		if let soundPath = Bundle.main.path(forResource: name, ofType: "caf") {
			let soundURL = URL(fileURLWithPath: soundPath)
			var mySound: SystemSoundID = 0
			AudioServicesCreateSystemSoundID(soundURL as CFURL, &mySound)
			AudioServicesPlaySystemSound(mySound);
		}
	}
	
	func cleanChatMessages(completion: @escaping () -> Void) {
		guard let storage = MobileMessaging.mobileChat?.defaultChatStorage else {
			completion()
			return
		}
		storage.removeAllMessages(completion: { _ in
			completion()
		})
	}
}
