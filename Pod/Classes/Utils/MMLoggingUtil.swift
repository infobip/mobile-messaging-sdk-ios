//
//  MMLoggingUtil.swift
//  MobileMessaging
//
//  Created by okoroleva on 15.03.16.
//  
//

import CocoaLumberjack

public final class MMLoggingOptions : NSObject {
	let rawValue: Int
	init(rawValue: Int) { self.rawValue = rawValue }
	public init(options: [MMLoggingOptions]) {
		let totalValue = options.reduce(0) { (total, option) -> Int in
			return total | option.rawValue
		}
		self.rawValue = totalValue
	}
	public func contains(_ options: MMLoggingOptions) -> Bool {
		return rawValue & options.rawValue != 0
	}
    public static let None = MMLoggingOptions(rawValue: 0)
    public static let Console = MMLoggingOptions(rawValue: 1 << 0)
    public static let ASL = MMLoggingOptions(rawValue: 1 << 1) //Apple System Logs
    public static let File = MMLoggingOptions(rawValue: 1 << 2)
}

/**
Logging utility is used for:
- setting up logging options and logging levels.
- obtaining a path to the logs file, in case the Logging utility is set up to log in file (logging options contains `.File` option).
*/
public final class MMLoggingUtil: NSObject {
    /**
     Path to the log file.
     Non null, if loggingOption contains .File
     */
    public var logFilePath: String? {
        guard let filelogger = self.fileLogger else {
            return nil
        }
        
       return filelogger.currentLogFileInfo().filePath
    }
	
    init(loggingOptions: MMLoggingOptions, logLevel: MMLogLevel) {
        self.loggingOptions = loggingOptions
        super.init()
        prepareLogging(logLevel.ddlogLevel())
    }
    
    convenience override init() {
        let loggingOptions: MMLoggingOptions
        #if DEBUG
            loggingOptions = .Console
        #else
            loggingOptions = .File
        #endif
        self.init(loggingOptions:loggingOptions, logLevel: .Warning)
    }
    
    /**
     This method set logging options for Mobile Messaging library.
     - parameter loggingOptions: An array of `MMLoggingOptions` instances to setup log outputs. For debug scheme default value is `Console`. For release sheme default value is `File`.
     - parameter logLevel: Log level is used to filter out logs sent to output. Default value is `Warning`.
     */
    public func setLoggingOptions(_ options:[MMLoggingOptions], logLevel: MMLogLevel) {
        let opts = MMLoggingOptions(options: options)
        DDLog.removeAllLoggers()
        self.loggingOptions = opts
        prepareLogging(logLevel.ddlogLevel())
    }
	
	public func sendLogs(fromViewController vc: UIViewController) {
		var objectsToShare: [Any] = [MobileMessaging.userAgent.currentUserAgentString]
		
		if let dt = MobileMessaging.currentInstallation?.deviceToken {
			objectsToShare.append("APNS device token: \(dt)")
		}
		
		if let id = MobileMessaging.currentUser?.internalId {
			objectsToShare.append("Push registration ID: \(id)")
		}
		
		if let filePath = MobileMessaging.loggingUtil.logFilePath {
			let url = NSURL(fileURLWithPath: filePath)
			objectsToShare.append(url)
			
			let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
			vc.present(activityVC, animated: true, completion: nil)
		}
	}
	
	//MARK: Private
    private var loggingOptions: MMLoggingOptions
    private var fileLogger: DDFileLogger?
    
    private func prepareLogging(_ logLevel: DDLogLevel) {
        
        if self.loggingOptions.contains(.Console) {
            let logger = DDTTYLogger.sharedInstance()
            logger?.logFormatter = MMLogFormatter()
            DDLog.add(logger, with: logLevel) //Console
        }
        
        if self.loggingOptions.contains(.ASL) {
            let logger = DDASLLogger.sharedInstance()
            logger?.logFormatter = MMLogFormatter()
            DDLog.add(logger, with: logLevel) //ASL
        }
        
        if self.loggingOptions.contains(.File) {
            self.fileLogger = DDFileLogger()
            if let fileLogger = self.fileLogger {
                fileLogger.logFormatter = MMLogFormatter()
                fileLogger.logFileManager.maximumNumberOfLogFiles = 10
                fileLogger.rollingFrequency = 60*60*24 //24h
            }
            DDLog.add(fileLogger, with: logLevel)
        }
    }
}

final class MMLogFormatter: NSObject, DDLogFormatter {
    let dateFormatter: DateFormatter
    override init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
    }
	func formatLogMessage(_ logMessage: DDLogMessage!) -> String! {
		let date = dateFormatter.string(from: logMessage.timestamp)
		return date + " [MobileMessaging] " + logMessage.message
	}
}
