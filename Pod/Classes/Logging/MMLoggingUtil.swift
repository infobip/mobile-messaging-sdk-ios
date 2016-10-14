
@objc public protocol MMLogging {
	var logOutput: MMLogOutput {set get}
	var logLevel: MMLogLevel {set get}
	var logFilePath: String? {get}
	func sendLogs(fromViewController vc: UIViewController)
	func logDebug(message: String)
	func logInfo(message: String)
	func logError(message: String)
	func logWarn(message: String)
	func logVerbose(message: String)
}

public func MMLogDebug(message: String) {
	MobileMessaging.logger.logDebug(message)
}

public func MMLogSecureDebug(message: String) {
	#if DEBUG
	MobileMessaging.logger.logDebug(message)
	#endif
}

public func MMLogInfo(message: String) {
	MobileMessaging.logger.logInfo(message)
}

public func MMLogWarn(message: String) {
	MobileMessaging.logger.logWarn(message)
}

public func MMLogVerbose(message: String) {
	MobileMessaging.logger.logVerbose(message)
}

public func MMLogError(message: String) {
	MobileMessaging.logger.logError(message)
}

public final class MMLogOutput : NSObject {
	let rawValue: Int
	init(rawValue: Int) { self.rawValue = rawValue }
	public init(options: [MMLogOutput]) {
		let totalValue = options.reduce(0) { (total, option) -> Int in
			return total | option.rawValue
		}
		self.rawValue = totalValue
	}
	public func contains(options: MMLogOutput) -> Bool {
		return rawValue & options.rawValue != 0
	}
	public static let None = MMLogOutput(rawValue: 0)
	public static let Console = MMLogOutput(rawValue: 1 << 0)
	public static let ASL = MMLogOutput(rawValue: 1 << 1) //Apple System Logs
	public static let File = MMLogOutput(rawValue: 1 << 2)
}

@objc public enum MMLogLevel : UInt {
	/// No logs
	case Off
	
	/// Error logs only
	case Error
	
	/// Error and warning logs
	case Warning
	
	/// Error, warning and info logs
	case Info
	
	/// Error, warning, info and debug logs
	case Debug
	
	/// Error, warning, info, debug and verbose logs
	case Verbose
	case All
}