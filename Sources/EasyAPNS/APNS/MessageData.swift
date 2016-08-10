//
//  MessageData.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 14.07.2016.
//
//

public extension Message {
    
    /**
     * Message's errors
     */
    public enum Error: Swift.Error, CustomStringConvertible {
        case incorrectDeviceTokenLength, payloadTooLarge, exceededSendingLimit
        
        public var description: String {
            switch self {
            case .incorrectDeviceTokenLength:
                return "DeviceToken length must be equal to 64"
            case .payloadTooLarge:
                return "PayLoad size must be less or equal than \(Message.maximumSize) bytes"
            case .exceededSendingLimit:
                return "Exceeded limit of sendveing retry"
            }
        }
    }
    
    /**
     * APNS's message sound representation
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
     * Wrapper to handle APNS's alerts
     */
    public enum Alert {
        
        /**
         * Detailed APNS's alert representation
         */
        public struct Detailed {
            public var title: String?
            public var body: String?
            public var titleLocKey: String?
            public var titleLocArgs: String?
            public var actionLocKey: String?
            public var locKey: String?
            public var locArgs: [String]
            public var launchImage: String?
            
            public var flat: [String: JSON] {
                var data = [String: JSON]()
                if let title = title {
                    data["title"] = JSON.infer(title)
                }
                if let body = body {
                    data["body"] = JSON.infer(body)
                }
                if let titleLocKey = titleLocKey {
                    data["title-loc-key"] = JSON.infer(titleLocKey)
                }
                if let actionLocKey = actionLocKey {
                    data["action-loc-key"] = JSON.infer(actionLocKey)
                }
                if let locKey = locKey {
                    data["loc-key"] = JSON.infer(locKey)
                }
                if let launchImage = launchImage {
                    data["launch-image"] = JSON.infer(launchImage)
                }
                if !locArgs.isEmpty {
                    data["loc-args"] = JSON.infer(locArgs.map {JSON.infer($0)})
                }
                return data
            }
            
            /**
             * JSON representation
             */
            public var json: JSON {
                return JSON.infer(flat)
            }
            
            /**
             * JSON string representation
             */
            public var jsonString: String {
                return JSONSerializer().serializeToString(json: json)
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
        
        case message(String), detailed(Detailed)
        
        /**
         * JSON representation
         */
        public var json: JSON {
            switch self {
            case .message(let str):
                return JSON.infer(str)
            case .detailed(let alert):
                return alert.json
            }
        }
        
        /**
         * JSON string representation 
         */
        public var jsonString: String {
            return JSONSerializer().serializeToString(json: json)
            
        }
    }

}
