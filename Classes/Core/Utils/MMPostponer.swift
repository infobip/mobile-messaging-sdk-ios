//
//  MMPostponer.swift
//
//  Created by Andrey K. on 05/07/16.
//

import Foundation
class MMPostponer: NSObject {
	private var block: (() -> Void)?
	private var schedulerQueue = MMQueue.Serial.newQueue(queueName: "com.mobile-messaging.queue.serial.postponer")
	private var timer: DispatchSourceTimer?
	private var executionQueue: DispatchQueue
	
	init(executionQueue: DispatchQueue) {
		self.executionQueue = executionQueue
	}
	
	func postponeBlock(delay: Double = 2, block: @escaping () -> Void) {
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
		timer?.cancel()
	}
	
	private func createDispatchTimer(_ delay: Double, queue: DispatchQueue, block: @escaping () -> Void) -> DispatchSourceTimer {
		let timer : DispatchSourceTimer = DispatchSource.makeTimerSource(queue: queue)
		timer.scheduleOneshot(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(Int(delay)),
		                      leeway: DispatchTimeInterval.seconds(0))
		timer.setEventHandler(handler: block)
		timer.resume()
		return timer
	}
}
