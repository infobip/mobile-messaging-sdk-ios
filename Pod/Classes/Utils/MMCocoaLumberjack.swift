import Foundation
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
    
    func ddlogLevel() -> DDLogLevel {
        switch self {
        case .Off: return DDLogLevel.off
        case .Error: return DDLogLevel.error
        case .Warning: return DDLogLevel.warning
        case .Info: return DDLogLevel.info
        case .Debug: return DDLogLevel.debug
        case .Verbose: return DDLogLevel.verbose
        case .All: return DDLogLevel.all
        }
    }
}

public var defaultDebugLevel = DDLogLevel.verbose

public func resetDefaultDebugLevel() {
    defaultDebugLevel = DDLogLevel.verbose
}

public func SwiftLogMacro(_ isAsynchronous: Bool, level: DDLogLevel, flag flg: DDLogFlag, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, string: @autoclosure () -> String) {
    if level.rawValue & flg.rawValue != 0 {
        // Tell the DDLogMessage constructor to copy the C strings that get passed to it.
        // Using string interpolation to prevent integer overflow warning when using StaticString.stringValue
        let logMessage = DDLogMessage(message: string(), level: level, flag: flg, context: context, file: "\(file)", function: "\(function)", line: line, tag: tag, options: [.copyFile, .copyFunction], timestamp: nil)
		DDLog.log(isAsynchronous, message: logMessage)
    }
}

public func MMLogDebug(_ logText: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = mmContext, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true) {
    SwiftLogMacro(async, level: level, flag: .debug, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

public func MMLogInfo(_ logText: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = mmContext, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true) {
    SwiftLogMacro(async, level: level, flag: .info, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

public func MMLogWarn(_ logText: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = mmContext, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true) {
    SwiftLogMacro(async, level: level, flag: .warning, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

public func MMLogVerbose(_ logText: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = mmContext, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true) {
    SwiftLogMacro(async, level: level, flag: .verbose, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

public func MMLogError(_ logText: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = mmContext, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = false) {
    SwiftLogMacro(async, level: level, flag: .error, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

/// Analogous to the C preprocessor macro `THIS_FILE`.
public func CurrentFileName(fileName: StaticString = #file) -> String {
    // Using string interpolation to prevent integer overflow warning when using StaticString.stringValue
    // This double-casting to NSString is necessary as changes to how Swift handles NSPathUtilities requres the string to be an NSString
    return (("\(fileName)" as NSString).lastPathComponent as NSString).deletingPathExtension
}

private let mmContext = 100
