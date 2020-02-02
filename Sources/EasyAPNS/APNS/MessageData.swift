//
//  MessageData.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 14.07.2016.
//
//

public extension Message {
  /// Message validation errors
  ///
  /// - incorrectDeviceTokenLength: DeviceToken length must be equal to 64
  /// - payloadTooLarge: PayLoad size must be less or equal than 4096 bytes in case of regular notifications and 5120 bytes for VOIP
  /// - incorrectPriority: If the notification contains only content-available key and no other, only low priority is allowed
  /// - collapseIdTooLarge: Maximum size of collapse id is 64 bytes
  public enum ValidationError: Swift.Error {
    case incorrectDeviceTokenLength
    case payloadTooLarge(maxSize: Int)
    case incorrectPriority
    case collapseIdTooLarge
  }
  /**
     APNS's message sound representation
     */
  public enum Sound: CustomStringConvertible {
    case `default`, custom(String)
    public var description: String {
      switch self {
      case .default: return "default"
      case .custom(let str): return str
      }
    }
  }
  /**
     Wrapper to handle APNS's alerts
     */
  public enum Alert: Codable {
    /**
         Detailed APNS's alert representation
         */
    public struct Detailed: Codable {

      enum CodingKeys: String, CodingKey {

        case title
        case body
        case titleLocKey = "title-loc-key"
        case actionLocKey = "action-loc-key"
        case locKey = "loc-key"
        case launchImage = "launch-image"
        case locArgs = "loc-args"
      }

      public var title: String?
      public var body: String?
      public var titleLocKey: String?
      public var titleLocArgs: String?
      public var actionLocKey: String?
      public var locKey: String?
      public var locArgs: [String] = []
      public var launchImage: String?
      public init(
        title: String? = nil,
        body: String? = nil,
        titleLocKey: String? = nil,
        titleLocArgs: String? = nil,
        actionLocKey: String? = nil,
        locKey: String? = nil,
        locArgs: [String] = [],
        launchImage: String? = nil
      ) {
        self.title = title
        self.body = body
        self.titleLocKey = titleLocKey
        self.titleLocArgs = titleLocArgs
        self.actionLocKey = actionLocKey
        self.locKey = locKey
        self.launchImage = launchImage
        self.locArgs = locArgs
      }
    }
    case message(String)
    case detailed(Detailed)

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()

      switch self {
      case .message(let msg): try container.encode(msg)
      case .detailed(let detail): try container.encode(detail)
      }
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()

      if let detailed = try? container.decode(Detailed.self) {
        self = .detailed(detailed)
      }

      self = .message(try container.decode(String.self))
    }
  }

  public struct Payload: Encodable {

    enum CodingKeys: String, CodingKey {

      case alert, badge, sound, category
      case contentAvailable = "content-available"
      case mutableContent = "mutable-content"
      case threadId = "thread-id"
    }

    public var alert: Alert? = nil

    public var badge: Int64? = nil

    public var sound: Sound? = nil

    public var category: String? = nil

    /// If only this is present in the notification the priority must not be set to high
    public var contentAvailable: Bool = false

    public var mutableContent: Bool = false

    public var threadId: String? = nil

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encodeIfPresent(alert, forKey: .alert)
      try container.encodeIfPresent(badge, forKey: .badge)
      try container.encodeIfPresent(sound?.description, forKey: .sound)
      try container.encodeIfPresent(category, forKey: .category)
      try container.encodeIfPresent(threadId, forKey: .threadId)
      if contentAvailable { try container.encode(1, forKey: .contentAvailable) }
      if mutableContent { try container.encode(1, forKey: .mutableContent) }
    }

    public init(
      alert: Alert? = nil,
      badge: Int64? = nil,
      sound: Sound? = nil,
      category: String? = nil,
      contentAvailable: Bool = false,
      mutableContent: Bool = false,
      threadId: String? = nil
    ) {
      self.alert = alert
      self.badge = badge
      self.sound = sound
      self.category = category
      self.contentAvailable = contentAvailable
      self.mutableContent = mutableContent
      self.threadId = threadId
    }
  }
}
