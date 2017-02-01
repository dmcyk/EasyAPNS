//
//  Message.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//
import libc
import JSON
import Foundation

/**
 APNS's message
 */
public struct Message: JSONRepresentable {
    
    public enum Priority: Int {
        case high = 10
        case low = 5 
        
    }
    
    public enum Mode {
        case regular
        case voip
        
        var maximumSize: Int {
            switch self {
            case .regular:
                return 4096
            case .voip:
                return 5120
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
    
    public var alert: Alert? = nil
    
    public var badge: Int64? = nil
    
    public var sound: Sound? = nil
    
    /// JSON keys must start with "acme"
    public var customPayload: [String: JSON] = [:]
    
    public var category: String? = nil
    
    /// If only this is present in the notification the priority must not be set to high
    public var contentAvailable: Bool = false
    
    public var mutableContent: Bool = false
    
    public var threadId: String? = nil
    
    /// From APNS documentation: Multiple notifications with the same collapse identifier are displayed to the user as a single notification. The value of this key must not exceed 64 bytes.
    public var collapseId: String? = nil
    
    // 'acme' custom data payload
    public var custom: [String: JSON] = [:]
    
    
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
        for token in deviceTokens {
            try validate(deviceToken: token)
        }
    }
    
    
    public func validate(deviceToken: String) throws {
        if strlen(deviceToken) != 64 {
            throw Message.ValidationError.incorrectDeviceTokenLength
        }
    }
    
    /**
     validate message payload
     */
    public func validate() throws {
        for (k, _) in custom {
            guard k.hasPrefix("acme") else {
                throw ValidationError.customPayloadIncorrectKey
            }
        }
        
        if let collapseId = collapseId {
            if collapseId.characters.count > 64 {
                throw ValidationError.collapseIdTooLarge
            }
        }
        
        let json = encoded()
        
        if json.object!.keys.count == 1 {
            if json.object!["aps"].object!.keys.count == 1 && json.object!["aps"].object!.keys.first! == "content-available" {
                guard priority == .low else {
                    throw ValidationError.incorrectPriority
                }
            }
        }
        
        let jsonString = try json.serialized()
        if jsonString.characters.count > mode.maximumSize {
            throw ValidationError.payloadTooLarge(maxSize: mode.maximumSize)
        }
        
    }
    
    public func encoded() -> JSON {
 
        var data = [String: JSON]()
        if let alert = alert {
            data["alert"] = alert.encoded()
        }
        if let badge = badge {
            data["badge"] = JSON.integer(badge)
        }
        if let sound = sound {
            data["sound"] = JSON.string(sound.description)
        }
        if let category = category {
            data["category"] = JSON.string(category)
        }
        if contentAvailable {
            data["content-available"] = 1
        }
        
        if mutableContent {
            data["mutable-content"] = 1
        }
        
        if let threadId = threadId {
            data["thread-id"] = JSON.string(threadId)
        }
        
        var json = JSON.object(customPayload)
        json["aps"] = JSON.object(data)
        
        for (k, v) in custom {
            json[k] = v
        }
        
        return json
    }

}
