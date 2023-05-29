
import CocoaLumberjack
import MobileMessaging

extension MMLoggerFactory {
	public func createLogger() -> MMLogging {
		return MMLumberjackLogger()
	}
}

extension DDLogFlag {
	public static func fromLogLevel(logLevel: DDLogLevel) -> DDLogFlag {
		return DDLogFlag(rawValue: logLevel.rawValue)
	}
	
	///returns the log level, or the lowest equivalant.
	public func toLogLevel() -> DDLogLevel {
		if let ourValid = DDLogLevel(rawValue: self.rawValue) {
			return ourValid
		} else {
			let logFlag:DDLogFlag = self
			
			if logFlag.contains(.verbose) {
				return .verbose
			} else if logFlag.contains(.debug) {
				return .debug
			} else if logFlag.contains(.info) {
				return .info
			} else if logFlag.contains(.warning) {
				return .warning
			} else if logFlag.contains(.error) {
				return .error
			} else {
				return .off
			}
		}
	}
}

func lumberjackLogLevel(from mmLogLevel: MMLogLevel) -> DDLogLevel {
	switch mmLogLevel {
	case .Off: return DDLogLevel.off
	case .Error: return DDLogLevel.error
	case .Warning: return DDLogLevel.warning
	case .Info: return DDLogLevel.info
	case .Debug: return DDLogLevel.debug
	case .Verbose: return DDLogLevel.verbose
	case .All: return DDLogLevel.all
	}
}

/// Logging utility is used for:
/// - setting up logging options and logging levels.
/// - obtaining a path to the logs file, in case the Logging utility is set up to log in file (logging options contains `.File` option).
public final class MMLumberjackLogger: NSObject, MMLogging {
	let context = "mobilemessaging".stableHash
	

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
		SwiftLogMacro(true, level: .debug, flag: .debug, context: context, file: #file, function: #function, line: #line, tag: nil, string: message)
	}
	public func logInfo(message: String) {
		SwiftLogMacro(true, level: .info, flag: .info, context: context, file: #file, function: #function, line: #line, tag: nil, string: message)
	}
	public func logError(message: String) {
		SwiftLogMacro(true, level: .error, flag: .error, context: context, file: #file, function: #function, line: #line, tag: nil, string: message)
	}
	public func logWarn(message: String) {
		SwiftLogMacro(true, level: .warning, flag: .warning, context: context, file: #file, function: #function, line: #line, tag: nil, string: message)
	}
	public func logVerbose(message: String) {
		SwiftLogMacro(true, level: .verbose, flag: .verbose, context: context, file: #file, function: #function, line: #line, tag: nil, string: message)
	}
	
	/// Path to the logs file.
	///
	/// Non null, if `loggingOption` contains `.file`.
	public var logFilePaths: [String]? {
		guard let filelogger = self.fileLogger else {
			return nil
		}
		
		return filelogger.logFileManager.sortedLogFileInfos.map({ (info) -> String in
			return info.filePath
		}) // .currentLogFileInfo.filePath
	}
	
	public init(logOutput: MMLogOutput, logLevel: MMLogLevel) {
		self.logOutput = logOutput
		self.logLevel = logLevel
		super.init()
		prepareLogging()
	}
	
	convenience override init() {
		let logOutput: MMLogOutput
		let logLevel: MMLogLevel
		#if DEBUG || IO
			logOutput = .Console
			logLevel = .Info
		#else
			logOutput = .File
			logLevel = .Warning
		#endif
		self.init(logOutput: logOutput, logLevel: logLevel)
	}
	
	public func sendLogs(fromViewController vc: UIViewController) {
		var objectsToShare: [Any] = [MobileMessaging.userAgent.currentUserAgentString]

		let ins = MobileMessaging.sharedInstance?.resolveInstallation()
		if let dt = ins?.pushServiceToken {
			objectsToShare.append("APNS device token: \(dt)")
		}
		
		if let id = ins?.pushRegistrationId {
			objectsToShare.append("Push registration ID: \(id)")
		}
		

		self.logFilePaths?.forEach({ (path) in
			objectsToShare.append(NSURL(fileURLWithPath: path))
		})
		let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
		vc.present(activityVC, animated: true, completion: nil)

	}
	
	//MARK: Private
	private var fileLogger: DDFileLogger?
	
	private func prepareLogging() {
		let lumberjackLogLvl = lumberjackLogLevel(from: logLevel)
		
		if logOutput.contains(options: .Console) {
			if let logger = DDTTYLogger.sharedInstance {
				logger.logFormatter = MMLogFormatter()
				DDLog.add(logger, with: lumberjackLogLvl) //Console
			}
		}
		
        if logOutput.contains(options: .ASL) {
            let logger = DDOSLogger.sharedInstance
            logger.logFormatter = MMLogFormatter()
            DDLog.add(logger, with: lumberjackLogLvl) //ASL
        }
		
		if logOutput.contains(options: .File) {
			self.fileLogger = DDFileLogger()
			if let fileLogger = self.fileLogger {
				fileLogger.logFormatter = MMLogFormatter()
				fileLogger.logFileManager.maximumNumberOfLogFiles = 10
				fileLogger.rollingFrequency = TimeInterval(60*60*24) //24h
				DDLog.add(fileLogger, with: lumberjackLogLvl)
			}
		}
	}
	
	public func SwiftLogMacro(_ isAsynchronous: Bool, level: DDLogLevel, flag flg: DDLogFlag, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, string: @autoclosure () -> String) {
		if level.rawValue & flg.rawValue != 0 {
			// Tell the DDLogMessage constructor to copy the C strings that get passed to it.
			// Using string interpolation to prevent integer overflow warning when using StaticString.stringValue
			let logMessage = DDLogMessage(message: string(), level: level, flag: flg, context: context, file: "\(file)", function: "\(function)", line: line, tag: tag, options: [.copyFile, .copyFunction], timestamp: nil)
			DDLog.log(asynchronous: isAsynchronous, message: logMessage)
		}
	}
}

final class MMLogFormatter: NSObject, DDLogFormatter {
	func format(message logMessage: DDLogMessage) -> String? {
		let icon: LogIcons
		switch logMessage.level {
		case .info:
			icon = LogIcons.info
		case .verbose:
			icon = LogIcons.verbose
		case .debug:
			icon = LogIcons.debug
		case .warning:
			icon = LogIcons.warning
		case .error:
			icon = LogIcons.error
		case .all:
			icon = LogIcons.all
		case .off:
			icon = LogIcons.off
		@unknown default:
			fatalError()
		}
		return formattedLogEntry(date: logMessage.timestamp, icon: icon, message: logMessage.message)
	}
}
