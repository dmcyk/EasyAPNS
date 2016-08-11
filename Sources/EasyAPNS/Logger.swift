//
//  Logger.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 02.08.2016.
//
//

enum LogType: Int {
    case none = 0, error = 1, info = 2
}

/**
 Logging level - use for message delivery debuging
 */
public struct LoggerLevel: OptionSet {
    public let rawValue: Int
    
    public static let none = LoggerLevel(rawValue: 0)
    public static let error = LoggerLevel(rawValue: 1 << 0)
    public static let info = LoggerLevel(rawValue: 1 << 1)
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

final class Logger {
   
    var level: LoggerLevel
    
    init(loggerLevel: LoggerLevel) {
        self.level =  loggerLevel
    }
    
    func log(_ src: String, type: LogType) {
        if level.contains(LoggerLevel(rawValue: type.rawValue)) {
            print(src)
        }
    }
}

