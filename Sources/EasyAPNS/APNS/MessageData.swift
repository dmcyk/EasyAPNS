//
//  MessageData.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 14.07.2016.
//
//

import JSON

public extension Message {
    
    
    /// Message validation errors
    ///
    /// - incorrectDeviceTokenLength: DeviceToken length must be equal to 64
    /// - payloadTooLarge: PayLoad size must be less or equal than 4096 bytes in case of regular notifications and 5120 bytes for VOIP
    /// - incorrectPriority: If the notification contains only content-available key and no other, only low priority is allowed
    /// - customPayloadIncorrectKey: Custom payload has an incorrect key. The key must start with 'acme' phrase
    /// - collapseIdTooLarge: Maximum size of collapse id is 64 bytes
    public enum ValidationError: Swift.Error {
        case incorrectDeviceTokenLength
        case payloadTooLarge(maxSize: Int)
        case incorrectPriority
        case customPayloadIncorrectKey
        case collapseIdTooLarge
    }
    
    /**
     APNS's message sound representation
     */
    public enum Sound: CustomStringConvertible {
        case `default`, custom(String)
        
        public var description: String {
            switch self {
            case .default:
                return "default"
            case .custom(let str):
                return str
            }
        }
    }
    
    /**
     Wrapper to handle APNS's alerts
     */
    public enum Alert: JSONRepresentable {
        
        /**
         Detailed APNS's alert representation
         */
        public struct Detailed: JSONConvertible {
            public var title: String?
            public var body: String?
            public var titleLocKey: String?
            public var titleLocArgs: String?
            public var actionLocKey: String?
            public var locKey: String?
            public var locArgs: [String]
            public var launchImage: String?
            
            public func encoded() -> JSON {
                var data = [String: JSON]()
                if let title = title {
                    data["title"] = JSON.string(title)
                }
                if let body = body {
                    data["body"] = JSON.string(body)
                }
                if let titleLocKey = titleLocKey {
                    data["title-loc-key"] = JSON.string(titleLocKey)
                }
                if let actionLocKey = actionLocKey {
                    data["action-loc-key"] = JSON.string(actionLocKey)
                }
                if let locKey = locKey {
                    data["loc-key"] = JSON.string(locKey)
                }
                if let launchImage = launchImage {
                    data["launch-image"] = JSON.string(launchImage)
                }
                if !locArgs.isEmpty {
                    data["loc-args"] = JSON.array(locArgs.map {JSON.string($0)})
                }
                return JSON.object(data)
            }
            
            public init(json: JSON) throws {
                self.title = try? json.get("title")
                self.body = try? json.get("body")
                self.titleLocKey = try? json.get("titleLocKey")
                self.titleLocArgs = try? json.get("titleLocArgs")
                self.actionLocKey = try? json.get("actionLocKey")
                self.locKey = try? json.get("locKey")
                self.locArgs = (try? json.get("locArgs")) ?? []
                self.launchImage = try? json.get("launchImage")

            }
            
            public init(title: String? = nil, body: String? = nil, titleLocKey: String? = nil, titleLocArgs: String? = nil,
                        actionLocKey: String? = nil, locKey: String? = nil, locArgs: [String] = [], launchImage: String? = nil) {
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
    
        public func encoded() -> JSON {
            switch self {
            case .message(let str):
                return JSON.string(str)
            case .detailed(let alert):
                return alert.encoded()
            }
        }
        
    }

}
