//
//  MMThrottle.swift
//
//  Created by Andrey K. on 05/07/16.
//

import Foundation
class MMThrottle: NSObject {
	private var block: (() -> Void)?
	private var schedulerQueue = MMQueue.Serial.newQueue("com.mobile-messaging.queue.serial.throttle")
	private var timer: dispatch_source_t?
	private var executionQueue: dispatch_queue_t
	
	init(executionQueue: dispatch_queue_t) {
		self.executionQueue = executionQueue
	}
	
	func postponeBlock(delay: Double = 2, block: Void -> Void) {
		schedulerQueue.executeAsync {
			self.invalidateTimer()
			self.block = block
			self.timer = self.createDispatchTimer(delay, queue: self.executionQueue, block:
				{
					var blockToExecute: (() -> Void)?
					self.schedulerQueue.executeSync {
						blockToExecute = self.block
						self.invalidateTimer()
					}
					blockToExecute?()
				}
			)
		}
	}
	
	private func invalidateTimer() {
		self.block = nil
		if let timer = self.timer {
			dispatch_source_cancel(timer)
			self.timer = nil
		}
	}
	
	private func createDispatchTimer(delay: Double, queue: dispatch_queue_t, block: dispatch_block_t) -> dispatch_source_t {
		let result = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
		if (result != nil) {
			dispatch_source_set_timer(result, dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), DISPATCH_TIME_FOREVER, 0)
			dispatch_source_set_event_handler(result, block)
			dispatch_resume(result)
		}
		return result
	}
}
