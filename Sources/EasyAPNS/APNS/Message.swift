//
//  Message.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//
import libc
import JSON

public enum MessageError: ErrorProtocol, CustomStringConvertible {
    case incorrectDeviceTokenLength, payloadTooLarge, exceededSendingLimit
    
    public var description: String {
        switch self {
        case .incorrectDeviceTokenLength:
            return "DeviceToken length must be equal to 64"
        case .payloadTooLarge:
            return "PayLoad size must be less or equal than \(Message.maximumSize) bytes"
        case .exceededSendingLimit:
            return "Given message has exceeded limit of sending retry"
        }
    }
}

public struct Message {
    public static let maximumSize: UInt = 4096
    
    public var deviceTokens: [String]
    public var appBundle: String
    public var customId: String? = nil
    
    public var alert: Alert? = nil
    public var badge: Int? = nil
    public var sound: Sound? = nil
    public var custom: [String: JSON] = [:]
    public var category: String? = nil
    public var contentAvailable: Bool = false
    
    public init(deviceToken: String, appBundle: String) throws {
        self.appBundle = appBundle
        self.deviceTokens = [deviceToken]
        try validateDeviceTokens()
    }
    
    public init(deviceTokens: [String], appBundle: String) throws {
        self.appBundle = appBundle
        self.deviceTokens = deviceTokens
        try validateDeviceTokens()
        
    }
    
    public func validateDeviceTokens() throws {
        for token in deviceTokens {
            try validate(deviceToken: token)
        }
    }
    
    public func validate(deviceToken: String) throws {
        if strlen(deviceToken) != 64 {
            throw MessageError.incorrectDeviceTokenLength
        }
    }
    
    public func validatePayload() throws {
        
        if strlen(jsonString) > Message.maximumSize {
            throw MessageError.payloadTooLarge
        }
    }
    
    public var flatAps: [String: JSON] {
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
    
    
    public var json: JSON {
        var json = JSON.infer(custom)
        json["aps"] = JSON.infer(flatAps)
        return json
    }
    
    public var jsonString: String {
        return JSONSerializer().serializeToString(json: json)
    }
    
}
