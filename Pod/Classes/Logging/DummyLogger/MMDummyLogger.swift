//
//  MMDummyLogger.swift
//
//  Created by Andrey K. on 13/09/16.
//
//

import Foundation

public final class MMLogger: NSObject, MMLogging {
	public var logLevel: MMLogLevel = MMLogLevel.Off
	public var logOutput: MMLogOutput = MMLogOutput.None
	public var logFilePath: String? = nil
	public func sendLogs(fromViewController vc: UIViewController) { }
	public func logDebug(message: String) { }
	public func logInfo(message: String) { }
	public func logError(message: String) { }
	public func logWarn(message: String) { }
	public func logVerbose(message: String) { }
}