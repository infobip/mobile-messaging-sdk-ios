
import CocoaLumberjack

extension DDLogFlag {
	public static func fromLogLevel(logLevel: DDLogLevel) -> DDLogFlag {
		return DDLogFlag(rawValue: logLevel.rawValue)
	}
	
	public init(_ logLevel: DDLogLevel) {
		self = DDLogFlag(rawValue: logLevel.rawValue)
	}
	
	///returns the log level, or the lowest equivalant.
	public func toLogLevel() -> DDLogLevel {
		if let ourValid = DDLogLevel(rawValue: self.rawValue) {
			return ourValid
		} else {
			let logFlag:DDLogFlag = self
			
			if logFlag.contains(.Verbose) {
				return .Verbose
			} else if logFlag.contains(.Debug) {
				return .Debug
			} else if logFlag.contains(.Info) {
				return .Info
			} else if logFlag.contains(.Warning) {
				return .Warning
			} else if logFlag.contains(.Error) {
				return .Error
			} else {
				return .Off
			}
		}
	}
}

func lumberjackLogLevel(from mmLogLevel: MMLogLevel) -> DDLogLevel {
	switch mmLogLevel {
	case .Off: return DDLogLevel.Off
	case .Error: return DDLogLevel.Error
	case .Warning: return DDLogLevel.Warning
	case .Info: return DDLogLevel.Info
	case .Debug: return DDLogLevel.Debug
	case .Verbose: return DDLogLevel.Verbose
	case .All: return DDLogLevel.All
	}
}

/// Logging utility is used for:
/// - setting up logging options and logging levels.
/// - obtaining a path to the logs file, in case the Logging utility is set up to log in file (logging options contains `.File` option).
public final class MMLogger: NSObject, MMLogging {
	let context = "mobilemessaging".hash
	

	/// An array of `MMLoggingOptions` instances to setup log outputs. For debug builds, default value is `Console`. For release builds, default value is `File`.
	public var logOutput: MMLogOutput {
		didSet {
			DDLog.removeAllLoggers()
			prepareLogging()
		}
	}
	
	/// Logging level is used to filter out logs sent to output. Default value is `.warning`.
	public var logLevel: MMLogLevel {
		didSet {
			DDLog.removeAllLoggers()
			prepareLogging()
		}
	}
	
	public func logDebug(message: String) {
		SwiftLogMacro(true, level: .Debug, flag: .Debug, context: context, file: #file, function: #function, line: #line, tag: nil, string: message)
	}
	public func logInfo(message: String) {
		SwiftLogMacro(true, level: .Info, flag: .Info, context: context, file: #file, function: #function, line: #line, tag: nil, string: message)
	}
	public func logError(message: String) {
		SwiftLogMacro(true, level: .Error, flag: .Error, context: context, file: #file, function: #function, line: #line, tag: nil, string: message)
	}
	public func logWarn(message: String) {
		SwiftLogMacro(true, level: .Warning, flag: .Warning, context: context, file: #file, function: #function, line: #line, tag: nil, string: message)
	}
	public func logVerbose(message: String) {
		SwiftLogMacro(true, level: .Verbose, flag: .Verbose, context: context, file: #file, function: #function, line: #line, tag: nil, string: message)
	}
	
	/// Path to the logs file.
	///
	/// Non null, if `loggingOption` contains `.file`.
	public var logFilePath: String? {
		guard let filelogger = self.fileLogger else {
			return nil
		}
		
		return filelogger.currentLogFileInfo().filePath
	}
	
	init(logOutput: MMLogOutput, logLevel: MMLogLevel) {
		self.logOutput = logOutput
		self.logLevel = logLevel
		super.init()
		prepareLogging()
	}
	
	convenience override init() {
		let logOutput: MMLogOutput
		#if DEBUG
			logOutput = .Console
		#else
			logOutput = .File
		#endif
		self.init(logOutput: logOutput, logLevel: .Warning)
	}
	
	public func sendLogs(fromViewController vc: UIViewController) {
		var objectsToShare: [AnyObject] = [MobileMessaging.userAgent.currentUserAgentString]
		
		if let dt = MobileMessaging.currentInstallation?.deviceToken {
			objectsToShare.append("APNS device token: \(dt)")
		}
		
		if let id = MobileMessaging.currentUser?.internalId {
			objectsToShare.append("Push registration ID: \(id)")
		}
		
		if let filePath = self.logFilePath {
			let url = NSURL(fileURLWithPath: filePath)
			objectsToShare.append(url)
			
			let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
			vc.presentViewController(activityVC, animated: true, completion: nil)
		}
	}
	
	//MARK: Private
	private var fileLogger: DDFileLogger?
	
	private func prepareLogging() {
		let lumberjackLogLvl = lumberjackLogLevel(from: logLevel)
		
		if logOutput.contains(.Console) {
			let logger = DDTTYLogger.sharedInstance()
			logger.logFormatter = MMLogFormatter()
			DDLog.addLogger(logger, withLevel: lumberjackLogLvl) //Console
		}
		
		if logOutput.contains(.ASL) {
			let logger = DDASLLogger.sharedInstance()
			logger.logFormatter = MMLogFormatter()
			DDLog.addLogger(logger, withLevel: lumberjackLogLvl) //ASL
		}
		
		if logOutput.contains(.File) {
			self.fileLogger = DDFileLogger()
			if let fileLogger = self.fileLogger {
				fileLogger.logFormatter = MMLogFormatter()
				fileLogger.logFileManager.maximumNumberOfLogFiles = 10
				fileLogger.rollingFrequency = 60*60*24 //24h
			}
			DDLog.addLogger(fileLogger, withLevel: lumberjackLogLvl)
		}
	}
	
	public func SwiftLogMacro(isAsynchronous: Bool, level: DDLogLevel, flag flg: DDLogFlag, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, @autoclosure string: () -> String) {
		if level.rawValue & flg.rawValue != 0 {
			// Tell the DDLogMessage constructor to copy the C strings that get passed to it.
			// Using string interpolation to prevent integer overflow warning when using StaticString.stringValue
			let logMessage = DDLogMessage(message: string(), level: level, flag: flg, context: context, file: "\(file)", function: "\(function)", line: line, tag: tag, options: [.CopyFile, .CopyFunction], timestamp: nil)
			DDLog.log(isAsynchronous, message: logMessage)
		}
	}
}

final class MMLogFormatter: NSObject, DDLogFormatter {
	let dateFormatter: NSDateFormatter
	override init() {
		self.dateFormatter = NSDateFormatter()
		self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
	}
	
	func formatLogMessage(logMessage: DDLogMessage!) -> String! {
		let date = dateFormatter.stringFromDate(logMessage.timestamp)
		return date + " [MobileMessaging] " + logMessage.message
	}
}
