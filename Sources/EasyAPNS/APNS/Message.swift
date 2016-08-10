//
//  Message.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//
import libc
import JSON


/**
 * APNS's message representation
 */
public struct Message {
    
    /**
     * maximum message size (increased to 4096 with APNS 2 [HTTP/2])
     */
    public static let maximumSize: UInt = 4096
    
    /**
     * device tokens that given message is supposed to be sent to
     */
    public var deviceTokens: [String]
    
    /**
     * application's bundle id
     */
    public var appBundle: String
    
    /**
     * custom message id, if nil APNS generates id on it's own
     */
    public var customId: String? = nil
    
    /**
     * alert in given message notification
     */
    public var alert: Alert? = nil
    
    /**
     * application badge
     */
    public var badge: Int? = nil
    
    /**
     * sound change
     */
    public var sound: Sound? = nil
    
    /**
     * additional custom payload
     */
    public var custom: [String: JSON] = [:]
    
    public var category: String? = nil
    public var contentAvailable: Bool = false
    
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
    
    /**
     * validate assigned device tokens
     */
    public func validateDeviceTokens() throws {
        for token in deviceTokens {
            try validate(token)
        }
    }
    
    /**
     * validate given device token
     */
    public func validate(_ deviceToken: String) throws {
        if strlen(deviceToken) != 64 {
            throw Message.Error.incorrectDeviceTokenLength
        }
    }
    
    /**
     * validate message payload length
     */
    public func validatePayload() throws {
        
        if strlen(jsonString) > Message.maximumSize {
            throw Message.Error.payloadTooLarge
        }
    }
    
    private var flatAps: [String: JSON] {
        var data = [String: JSON]()
        if let alert = alert {
            data["alert"] = alert.json
        }
        if let badge = badge {
            data["badge"] = JSON.infer(badge)
        }
        if let sound = sound {
            data["sound"] = JSON.infer(sound.description)
        }
        if let category = category {
            data["category"] = JSON.infer(category)
        }
        if contentAvailable {
            data["content-available"] = 1
        }
        return data
    }
    
    /**
     * JSON representation
     */
    public var json: JSON {
        var json = JSON.infer(custom)
        json["aps"] = JSON.infer(flatAps)
        return json
    }
    
    /**
     * JSON string representation
     */
    public var jsonString: String {
        return JSONSerializer().serializeToString(json: json)
    }
    
}
