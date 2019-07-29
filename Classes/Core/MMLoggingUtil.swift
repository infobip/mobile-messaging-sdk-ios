
@objc protocol MMLoggerFactoryProtocol {
	@objc optional func createLogger() -> MMLogging
}

@objc class MMLoggerFactory: NSObject, MMLoggerFactoryProtocol {}

// uncomment this if you need logs but don't like CocoaLumberjack. Simple MMDefaultLogger without filtering will be printing to the console for you.
//extension MMLoggerFactory {
//    public func createLogger() -> MMLogging {
//        return MMDefaultLogger()
//    }
//}

public final class MMDefaultLogger: NSObject, MMLogging {
    public var logOutput: MMLogOutput
    
    public var logLevel: MMLogLevel = .All
    
    public var logFilePath: String? = nil
    
    public func sendLogs(fromViewController vc: UIViewController) {
        
    }

	public override init() {
		self.logOutput = .Console
	}

	private func log(_ icon: LogIcons, _ message: String) {
		guard logOutput == .Console else {
			return
		}
		print(formattedLogEntry(date: Date(), icon: icon, message: message))
	}

    public func logDebug(message: String) {
        log(LogIcons.debug, message)
    }
    
    public func logInfo(message: String) {
        log(LogIcons.info, message)
    }
    
    public func logError(message: String) {
        log(LogIcons.error, message)
    }
    
    public func logWarn(message: String) {
        log(LogIcons.warning, message)
    }
    
    public func logVerbose(message: String) {
        log(LogIcons.verbose, message)
    }
}

enum LogIcons: String {
	case info = "ℹ️"
	case verbose = "💬"
	case debug = "🛠"
	case warning = "⚠️"
	case error = "‼️"
	case all = "ALL"
	case off = "OFF"
}

func formattedLogEntry(date: Date, icon: LogIcons, message: String) -> String {
	return "\(DateStaticFormatters.LoggerDateFormatter.string(from: date)) [MobileMessaging] \(icon.rawValue) \(message)"
}

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

public func MMLogDebug(_ message: String) {
	MobileMessaging.logger?.logDebug(message: message)
}

public func MMLogSecureDebug(_ message: String) {
	#if DEBUG
	MobileMessaging.logger?.logDebug(message: message)
	#endif
}

public func MMLogInfo(_ message: String) {
	MobileMessaging.logger?.logInfo(message: message)
}

public func MMLogWarn(_ message: String) {
	MobileMessaging.logger?.logWarn(message: message)
}

public func MMLogVerbose(_ message: String) {
	MobileMessaging.logger?.logVerbose(message: message)
}

public func MMLogError(_ message: String) {
	MobileMessaging.logger?.logError(message: message)
}

@objcMembers
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
	/**
	*  No logs
	*/
	case Off
	
	/**
	*  Error logs only
	*/
	case Error
	
	/**
	*  Error and warning logs
	*/
	case Warning
	
	/**
	*  Error, warning and info logs
	*/
	case Info
	
	/**
	*  Error, warning, info and debug logs
	*/
	case Debug
	
	/**
	*  Error, warning, info, debug and verbose logs
	*/
	case Verbose
	case All
//	
//	func ddlogLevel() -> DDLogLevel {
//		switch self {
//		case .Off: return DDLogLevel.off
//		case .Error: return DDLogLevel.error
//		case .Warning: return DDLogLevel.warning
//		case .Info: return DDLogLevel.info
//		case .Debug: return DDLogLevel.debug
//		case .Verbose: return DDLogLevel.verbose
//		case .All: return DDLogLevel.all
//		}
//	}
}
