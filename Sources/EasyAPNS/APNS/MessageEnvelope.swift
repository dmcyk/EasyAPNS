//
//  MessageEnvelope.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//

import JSON

/**
 * Message wrapper in `EasyAPNS` per device token, contains information about sending status of the wrapped message
 */
public struct MessageEnvelope {
    
    /**
     Sending status representation of `MessageEnvelope`
     */
    public enum Status: Equatable {
        case notSend
        case successfullySent(apnsId: String?, rawResponse: CurlResponse?)
        indirect case enqueuedForResend(innerState: Status?)
        case sendingFailed(Any)
        case responseParsingError(jsonParserErr: Any, rawResponse: CurlResponse?)
        case badRequest(BadRequestResponse)
        case errorWithCertificate
        case incorrectRequestMethod
        case deviceTokenNoLongerActive
        case payloadTooLarge
        case tooManyRequestsForGivenToken
        case serverError
        case serverShutdown
        case unknown
        
        public enum BadRequestResponse {
            case raw(json: JSON), reason(String)
        }
        
        public var rawValue: Int {
            switch self {
            case .notSend:
                return -1
            case .successfullySent:
                return 0
            case .enqueuedForResend(_):
                return 1
            case .sendingFailed:
                return 2
            case .responseParsingError(_,_):
                return 3
            case .badRequest:
                return 400
            case .errorWithCertificate:
                return 403
            case .incorrectRequestMethod:
                return 405
            case .deviceTokenNoLongerActive:
                return 410
            case .payloadTooLarge:
                return 413
            case .tooManyRequestsForGivenToken:
                return 429
            case .serverError:
                return 500
            case .serverShutdown:
                return 503
            case .unknown:
                return -2
            }
        }
        
        
        /**
         rawValue initialization only available for given APNS's incorrect response codes, other possibilities are ought
         to be set manually
         */
        init(rawValue: Int) {
            switch rawValue {
            case 403:
                self = .errorWithCertificate
            case 405:
                self = .incorrectRequestMethod
            case 410:
                self = .deviceTokenNoLongerActive
            case 413:
                self = .payloadTooLarge
            case 429:
                self = .tooManyRequestsForGivenToken
            case 500:
                self = .serverError
            case 503:
                self = .serverShutdown
            default:
                self = .unknown
            }
        }
        
        /**
         equitability set by rawValue
         */
        public static func ==(lhs: Status, rhs: Status) -> Bool {
            return lhs.rawValue == rhs.rawValue
        }
    }
    
    /**
     message referenced by envelope
     */
    public let message: Message
    
    /**
     device token that given envelope is supposed to be sent to
     */
    public let deviceToken: String
    
    /**
     current envelope's status
     */
    public internal(set) var status: Status
    
    /**
     current send retries count
     */
    public internal(set) var retriesCount: Int = 0
    
    /**
     - parameter message:Message message to include send with envelope
     - parameter deviceToken:String message's target device token
     */
    public init(_ message: Message, deviceToken: String) {
        self.deviceToken = deviceToken
        self.message = message
        self.status = .notSend
        
    }
    
}

