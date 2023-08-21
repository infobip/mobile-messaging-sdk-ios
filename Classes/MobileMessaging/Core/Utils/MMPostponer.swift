//
//  MMPostponer.swift
//
//  Created by Andrey K. on 05/07/16.
//

import Foundation
public class MMPostponer: NSObject {
	private var block: (() -> Void)?
	private var schedulerQueue = MMQueue.Serial.New.PostponerQueue.queue
	private var timer: DispatchSourceTimer?
	private var executionQueue: DispatchQueue
	
	public init(executionQueue: DispatchQueue) {
		self.executionQueue = executionQueue
	}
	
	public func postponeBlock(delay: Double = 2000, block: @escaping () -> Void) {
		schedulerQueue.async {
			self.invalidateTimer()
			self.block = block
			self.timer = self.createDispatchTimer(delay, queue: self.executionQueue, block:
				{
					var blockToExecute: (() -> Void)?
					self.schedulerQueue.sync {
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
		let deadline = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(delay))
        let leeway = DispatchTimeInterval.milliseconds(0)
		timer.schedule(deadline: deadline, leeway: leeway)
		timer.setEventHandler(handler: block)
		timer.resume()
		return timer
	}
}
