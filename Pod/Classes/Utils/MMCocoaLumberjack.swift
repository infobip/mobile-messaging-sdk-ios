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
        case .Off: return DDLogLevel.Off
        case .Error: return DDLogLevel.Error
        case .Warning: return DDLogLevel.Warning
        case .Info: return DDLogLevel.Info
        case .Debug: return DDLogLevel.Debug
        case .Verbose: return DDLogLevel.Verbose
        case .All: return DDLogLevel.All
        }
    }
}

public var defaultDebugLevel = DDLogLevel.Verbose

public func resetDefaultDebugLevel() {
    defaultDebugLevel = DDLogLevel.Verbose
}

public func SwiftLogMacro(isAsynchronous: Bool, level: DDLogLevel, flag flg: DDLogFlag, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, @autoclosure string: () -> String) {
    if level.rawValue & flg.rawValue != 0 {
        // Tell the DDLogMessage constructor to copy the C strings that get passed to it.
        // Using string interpolation to prevent integer overflow warning when using StaticString.stringValue
        let logMessage = DDLogMessage(message: string(), level: level, flag: flg, context: context, file: "\(file)", function: "\(function)", line: line, tag: tag, options: [.CopyFile, .CopyFunction], timestamp: nil)
        DDLog.log(isAsynchronous, message: logMessage)
    }
}

public func MMLogDebug(@autoclosure logText: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = mmContext, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = true) {
    SwiftLogMacro(async, level: level, flag: .Debug, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

public func MMLogInfo(@autoclosure logText: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = mmContext, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = true) {
    SwiftLogMacro(async, level: level, flag: .Info, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

public func MMLogWarn(@autoclosure logText: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = mmContext, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = true) {
    SwiftLogMacro(async, level: level, flag: .Warning, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

public func MMLogVerbose(@autoclosure logText: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = mmContext, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = true) {
    SwiftLogMacro(async, level: level, flag: .Verbose, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

public func MMLogError(@autoclosure logText: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = mmContext, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = false) {
    SwiftLogMacro(async, level: level, flag: .Error, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

/// Analogous to the C preprocessor macro `THIS_FILE`.
public func CurrentFileName(fileName: StaticString = #file) -> String {
    // Using string interpolation to prevent integer overflow warning when using StaticString.stringValue
    // This double-casting to NSString is necessary as changes to how Swift handles NSPathUtilities requres the string to be an NSString
    return (("\(fileName)" as NSString).lastPathComponent as NSString).stringByDeletingPathExtension
}

private let mmContext = 100
