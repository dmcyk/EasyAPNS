//
//  Logger.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 02.08.2016.
//
//

enum LogType: Int, CustomStringConvertible {
  case none = 0, error = 1, debug = 2, verbose = 4, warning = 8

  var description: String {
    let val: String
    switch self {
    case .none: val = "none"
    case .error: val = "error"
    case .debug: val = "debug"
    case .verbose: val = "verbose"
    case .warning: val = "warning"
    }
    return val.uppercased()
  }
}

/**
 Logging level - use for message delivery debuging
 */
public struct LoggerLevel: OptionSet {
  public let rawValue: Int
  public static let none = LoggerLevel(rawValue: 0)
  public static let error = LoggerLevel(rawValue: 1 << 0)
  public static let debug = LoggerLevel(rawValue: 1 << 1)
  public static let verbose = LoggerLevel(rawValue: 1 << 2)
  public static let warning = LoggerLevel(rawValue: 1 << 3)
  public init(rawValue: Int) { self.rawValue = rawValue }

  public static var allEnabled: LoggerLevel {
    return [.error, .debug, .verbose, .warning]
  }
}

final class Logger {

  static var shared: Logger = Logger()
  var level: LoggerLevel = .allEnabled
  private init() {}

  private func log(msg: Any, type: LogType) {
    if level.contains(LoggerLevel(rawValue: type.rawValue)) {
      print("[\(type)] \(msg)")
    }
  }
  func log(_ src: Any, type: LogType) {
    if level == .none { return }

    if type == .error { log(msg: src, type: type) } else {
      #if DEBUG
        log(msg: src, type: type)
      #endif
    }
  }
}

func log(_ message: @autoclosure () -> Any, type: LogType) {
  Logger.shared.log(message(), type: type)
}

func logWarning(_ message: @autoclosure () -> Any) {
  Logger.shared.log(message(), type: .warning)
}

func logError(_ message: @autoclosure () -> Any) {
  Logger.shared.log(message(), type: .error)
}

func logVerbose(_ message: @autoclosure () -> Any) {
  Logger.shared.log(message(), type: .verbose)
}

func logDebug(_ message: @autoclosure () -> Any) {
  Logger.shared.log(message(), type: .debug)
}
