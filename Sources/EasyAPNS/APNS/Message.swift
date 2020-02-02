//
//  Message.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//
import libc
import Foundation

/**
 APNS's message
 */
public struct Message {
  public enum Priority: Int {
    case high = 10
    case low = 5
  }
  public enum Mode {
    case regular
    case voip
    var maximumSize: Int {
      switch self {
      case .regular: return 4096
      case .voip: return 5120
      }
    }
  }
  /// Notification expiration mode
  ///
  /// - immediate: APNS will try to deliver the notification only once
  /// - at: from APNS documentation: 'UNIX epoch date expressed in seconds (UTC)', setting it to 0 equals to immediate expiration
  /// - `default`: unspecified, handled by APNS itself
  public enum Expiration {
    case immediate
    case at(Date)
    case `default`
  }
  public var priority: Priority = .high
  public var mode: Mode = .regular
  public var expiration: Expiration = .default

  /// device tokens that given message is supposed to be sent to
  public var deviceTokens: [String]

  /// application's bundle id
  public var appBundle: String

  /// custom message id, if nil APNS generates id on it's own - given in response
  public var customId: String? = nil

  /// From APNS documentation: Multiple notifications with the same collapse identifier are displayed to the user as a single notification. The value of this key must not exceed 64 bytes.
  public var collapseId: String? = nil

  public var payload: Payload = Payload() { willSet { encodedDataCache = nil } }

  public var customPayload: Encodable? { willSet { encodedDataCache = nil } }

  private var encodedDataCache: Data?

  // MARK: - Payload mapping
  public var alert: Alert? {
    get { return payload.alert }
    set { payload.alert = newValue }
  }

  public var badge: Int64? {
    get { return payload.badge }
    set { payload.badge = newValue }
  }

  public var sound: Sound? {
    get { return payload.sound }
    set { payload.sound = newValue }
  }

  public var category: String? {
    get { return payload.category }
    set { payload.category = newValue }
  }

  /// If only this is present in the notification the priority must be set to `low`
  public var contentAvailable: Bool {
    get { return payload.contentAvailable }
    set { payload.contentAvailable = newValue }
  }

  public var mutableContent: Bool {
    get { return payload.mutableContent }
    set { payload.mutableContent = newValue }
  }

  public var threadId: String? {
    get { return payload.threadId }
    set { payload.threadId = newValue }
  }

  /**
     - parameter deviceToken:String single device token to receive message
     - parameter appBundle:String app's bundle id that is to receive message
     */
  public init(deviceToken: String, appBundle: String) throws {
    self.appBundle = appBundle
    self.deviceTokens = [deviceToken]
    try validateDeviceTokens()
  }
  /**
     - parameter deviceToken:[String] collection device tokens to receive message
     - parameter appBundle:String app's bundle id that is to receive message
     */
  public init(deviceTokens: [String], appBundle: String) throws {
    self.appBundle = appBundle
    self.deviceTokens = deviceTokens
    try validateDeviceTokens()
  }
  private func validateDeviceTokens() throws {
    for token in deviceTokens { try validate(deviceToken: token) }
  }
  public func validate(deviceToken: String) throws {
    if deviceToken.bytesCount != 64 {
      throw Message.ValidationError.incorrectDeviceTokenLength
    }
  }

  public mutating func encodedData() throws -> Data {
    if let cache = encodedDataCache { return cache }

    struct FinalPayload: Encodable {

      enum CodingKeys: CodingKey {

        case aps
      }

      let aps: Payload
      let custom: Encodable?

      func encode(to encoder: Encoder) throws {
        // encode custom payload first
        try custom?.encode(to: encoder)

        // so that `aps` key get's overwritten in case it's been used
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(aps, forKey: .aps)
      }
    }

    let final = FinalPayload(aps: payload, custom: customPayload)
    let raw = try JSONEncoder().encode(final)
    encodedDataCache = raw
    return raw
  }
  /**
     validate message payload
     */
  @discardableResult public mutating func validate() throws -> Data {
    if let collapseId = collapseId {
      if collapseId.bytesCount > 64 { throw ValidationError.collapseIdTooLarge }
    }

    let data = try encodedData()

    if payload.contentAvailable && priority != .low {
      throw ValidationError.incorrectPriority
    }
    if data.count > mode.maximumSize {
      throw ValidationError.payloadTooLarge(maxSize: mode.maximumSize)
    }

    return data
  }
}
